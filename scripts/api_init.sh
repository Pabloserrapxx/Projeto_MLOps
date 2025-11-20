#!/bin/bash
set -e

# FastAPI + Streamlit Installation and Configuration Script
# This script sets up FastAPI and Streamlit for model serving and visualization

echo "=========================================="
echo "API/Streamlit Setup - Starting Installation"
echo "=========================================="

# Update system
echo "Updating system packages..."
sudo yum update -y

# Install Python 3.9 and dependencies
echo "Installing Python 3.9 and dependencies..."
sudo yum install -y python39 python39-pip python39-devel gcc gcc-c++ make git wget

# Set Python 3.9 as default
sudo alternatives --set python3 /usr/bin/python3.9

# Upgrade pip
python3 -m pip install --upgrade pip

# Install FastAPI, Uvicorn, Streamlit and dependencies
echo "Installing FastAPI, Streamlit and dependencies..."
pip3 install fastapi==0.109.0 \
    uvicorn[standard]==0.27.0 \
    streamlit==1.31.0 \
    mlflow==2.10.0 \
    pydantic==2.5.0 \
    python-multipart==0.0.6 \
    pandas==2.2.0 \
    numpy==1.26.0 \
    scikit-learn==1.4.0 \
    plotly==5.18.0 \
    requests==2.31.0 \
    oci==2.119.1

# Install OCI CLI
echo "Installing OCI CLI..."
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)" -- --accept-all-defaults

# Add OCI CLI to PATH
echo 'export PATH=$PATH:/root/bin' >> /home/opc/.bashrc
export PATH=$PATH:/root/bin

# Configure OCI
mkdir -p /home/opc/.oci
cat > /home/opc/.oci/config <<EOF
[DEFAULT]
region=${region}
EOF
chown -R opc:opc /home/opc/.oci

# Create application directory
APP_DIR=/home/opc/app
mkdir -p $APP_DIR

# Configure environment variables
cat > /home/opc/app.env <<EOF
export MLFLOW_TRACKING_URI="${mlflow_url}"
export FASTAPI_PORT=${fastapi_port}
export STREAMLIT_PORT=${streamlit_port}
export OCI_REGION="${region}"
EOF

source /home/opc/app.env
echo 'source /home/opc/app.env' >> /home/opc/.bashrc

# Create FastAPI application
cat > $APP_DIR/main.py <<'PYEOF'
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import mlflow
import mlflow.sklearn
import os
import logging
from typing import List, Dict, Any

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="MLOps Model Serving API",
    description="API for serving ML models with MLflow",
    version="1.0.0"
)

# MLflow configuration
MLFLOW_TRACKING_URI = os.getenv("MLFLOW_TRACKING_URI", "http://localhost:5000")
mlflow.set_tracking_uri(MLFLOW_TRACKING_URI)

# Global model cache
model_cache = {}

class PredictionInput(BaseModel):
    data: List[List[float]]
    
class PredictionOutput(BaseModel):
    predictions: List[Any]
    model_name: str
    model_version: str

@app.get("/")
def root():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "mlflow_uri": MLFLOW_TRACKING_URI,
        "message": "MLOps Model Serving API is running"
    }

@app.get("/models")
def list_models():
    """List all registered models"""
    try:
        client = mlflow.tracking.MlflowClient()
        models = client.search_registered_models()
        
        model_list = []
        for model in models:
            model_info = {
                "name": model.name,
                "latest_versions": [
                    {
                        "version": mv.version,
                        "stage": mv.current_stage,
                        "run_id": mv.run_id
                    }
                    for mv in model.latest_versions
                ]
            }
            model_list.append(model_info)
        
        return {"models": model_list}
    except Exception as e:
        logger.error(f"Error listing models: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/models/{model_name}/versions")
def list_model_versions(model_name: str):
    """List all versions of a specific model"""
    try:
        client = mlflow.tracking.MlflowClient()
        versions = client.search_model_versions(f"name='{model_name}'")
        
        version_list = [
            {
                "version": v.version,
                "stage": v.current_stage,
                "run_id": v.run_id,
                "status": v.status
            }
            for v in versions
        ]
        
        return {"model_name": model_name, "versions": version_list}
    except Exception as e:
        logger.error(f"Error listing model versions: {str(e)}")
        raise HTTPException(status_code=404, detail=str(e))

@app.post("/predict/{model_name}/{version}", response_model=PredictionOutput)
def predict(model_name: str, version: str, input_data: PredictionInput):
    """Make predictions using a specific model version"""
    try:
        # Load model from cache or MLflow
        cache_key = f"{model_name}:{version}"
        
        if cache_key not in model_cache:
            logger.info(f"Loading model {model_name} version {version}")
            model_uri = f"models:/{model_name}/{version}"
            model = mlflow.sklearn.load_model(model_uri)
            model_cache[cache_key] = model
        else:
            logger.info(f"Using cached model {cache_key}")
            model = model_cache[cache_key]
        
        # Make predictions
        predictions = model.predict(input_data.data)
        
        return PredictionOutput(
            predictions=predictions.tolist(),
            model_name=model_name,
            model_version=version
        )
    except Exception as e:
        logger.error(f"Prediction error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/predict/{model_name}/production", response_model=PredictionOutput)
def predict_production(model_name: str, input_data: PredictionInput):
    """Make predictions using the production version of a model"""
    return predict(model_name, "Production", input_data)

@app.delete("/cache")
def clear_cache():
    """Clear the model cache"""
    global model_cache
    model_cache = {}
    return {"message": "Model cache cleared"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=int(os.getenv("FASTAPI_PORT", 8000)))
PYEOF

# Create Streamlit application
cat > $APP_DIR/streamlit_app.py <<'PYEOF'
import streamlit as st
import requests
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import mlflow
import os
from datetime import datetime

# Configuration
MLFLOW_TRACKING_URI = os.getenv("MLFLOW_TRACKING_URI", "http://localhost:5000")
FASTAPI_URL = f"http://localhost:{os.getenv('FASTAPI_PORT', 8000)}"

mlflow.set_tracking_uri(MLFLOW_TRACKING_URI)

# Page config
st.set_page_config(
    page_title="MLOps Dashboard",
    page_icon="🤖",
    layout="wide"
)

# Title
st.title("🤖 MLOps Dashboard")
st.markdown("---")

# Sidebar
st.sidebar.title("Navigation")
page = st.sidebar.radio("Go to", ["📊 Models Overview", "🔮 Model Prediction", "📈 Experiments"])

if page == "📊 Models Overview":
    st.header("📊 Registered Models")
    
    try:
        # Fetch models from API
        response = requests.get(f"{FASTAPI_URL}/models")
        
        if response.status_code == 200:
            models = response.json()["models"]
            
            if not models:
                st.info("No models registered yet.")
            else:
                for model in models:
                    with st.expander(f"📦 {model['name']}"):
                        st.write("**Latest Versions:**")
                        
                        for version in model['latest_versions']:
                            col1, col2, col3 = st.columns(3)
                            col1.metric("Version", version['version'])
                            col2.metric("Stage", version['stage'])
                            col3.metric("Run ID", version['run_id'][:8] + "...")
        else:
            st.error(f"Error fetching models: {response.status_code}")
    
    except Exception as e:
        st.error(f"Error connecting to API: {str(e)}")

elif page == "🔮 Model Prediction":
    st.header("🔮 Model Prediction")
    
    try:
        # Fetch available models
        response = requests.get(f"{FASTAPI_URL}/models")
        
        if response.status_code == 200:
            models = response.json()["models"]
            
            if not models:
                st.warning("No models available for prediction.")
            else:
                model_names = [model['name'] for model in models]
                selected_model = st.selectbox("Select Model", model_names)
                
                # Fetch versions for selected model
                versions_response = requests.get(f"{FASTAPI_URL}/models/{selected_model}/versions")
                
                if versions_response.status_code == 200:
                    versions = versions_response.json()["versions"]
                    version_options = [v['version'] for v in versions]
                    selected_version = st.selectbox("Select Version", version_options)
                    
                    st.markdown("---")
                    st.subheader("Input Data")
                    
                    # Input method selection
                    input_method = st.radio("Input Method", ["Manual Entry", "Upload CSV"])
                    
                    if input_method == "Manual Entry":
                        num_features = st.number_input("Number of Features", min_value=1, max_value=20, value=4)
                        
                        features = []
                        cols = st.columns(min(num_features, 4))
                        
                        for i in range(num_features):
                            col_idx = i % 4
                            with cols[col_idx]:
                                value = st.number_input(f"Feature {i+1}", value=0.0, key=f"feat_{i}")
                                features.append(value)
                        
                        if st.button("🚀 Predict"):
                            with st.spinner("Making prediction..."):
                                payload = {"data": [features]}
                                pred_response = requests.post(
                                    f"{FASTAPI_URL}/predict/{selected_model}/{selected_version}",
                                    json=payload
                                )
                                
                                if pred_response.status_code == 200:
                                    result = pred_response.json()
                                    st.success("✅ Prediction Successful!")
                                    st.json(result)
                                else:
                                    st.error(f"Prediction failed: {pred_response.text}")
                    
                    else:  # Upload CSV
                        uploaded_file = st.file_uploader("Upload CSV file", type=['csv'])
                        
                        if uploaded_file is not None:
                            df = pd.read_csv(uploaded_file)
                            st.write("Preview of uploaded data:")
                            st.dataframe(df.head())
                            
                            if st.button("🚀 Predict Batch"):
                                with st.spinner("Making predictions..."):
                                    payload = {"data": df.values.tolist()}
                                    pred_response = requests.post(
                                        f"{FASTAPI_URL}/predict/{selected_model}/{selected_version}",
                                        json=payload
                                    )
                                    
                                    if pred_response.status_code == 200:
                                        result = pred_response.json()
                                        st.success("✅ Predictions Successful!")
                                        
                                        predictions_df = df.copy()
                                        predictions_df['Prediction'] = result['predictions']
                                        st.dataframe(predictions_df)
                                        
                                        # Download button
                                        csv = predictions_df.to_csv(index=False)
                                        st.download_button(
                                            label="📥 Download Results",
                                            data=csv,
                                            file_name=f"predictions_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv",
                                            mime="text/csv"
                                        )
                                    else:
                                        st.error(f"Prediction failed: {pred_response.text}")
        else:
            st.error("Error fetching models")
    
    except Exception as e:
        st.error(f"Error: {str(e)}")

elif page == "📈 Experiments":
    st.header("📈 Experiments & Runs")
    
    try:
        client = mlflow.tracking.MlflowClient()
        experiments = client.search_experiments()
        
        exp_names = [exp.name for exp in experiments if exp.name != "Default"]
        
        if not exp_names:
            st.info("No experiments found.")
        else:
            selected_exp = st.selectbox("Select Experiment", exp_names)
            
            # Get experiment by name
            experiment = client.get_experiment_by_name(selected_exp)
            
            # Get runs
            runs = client.search_runs(experiment_ids=[experiment.experiment_id])
            
            if not runs:
                st.info("No runs found in this experiment.")
            else:
                # Create DataFrame
                runs_data = []
                for run in runs:
                    run_data = {
                        "Run ID": run.info.run_id[:8],
                        "Status": run.info.status,
                        "Start Time": datetime.fromtimestamp(run.info.start_time / 1000).strftime('%Y-%m-%d %H:%M:%S')
                    }
                    run_data.update(run.data.metrics)
                    runs_data.append(run_data)
                
                runs_df = pd.DataFrame(runs_data)
                st.dataframe(runs_df)
                
                # Visualize metrics
                st.subheader("Metrics Comparison")
                
                metric_cols = [col for col in runs_df.columns if col not in ["Run ID", "Status", "Start Time"]]
                
                if metric_cols:
                    selected_metric = st.selectbox("Select Metric", metric_cols)
                    
                    fig = px.bar(runs_df, x="Run ID", y=selected_metric, title=f"{selected_metric} by Run")
                    st.plotly_chart(fig, use_container_width=True)
    
    except Exception as e:
        st.error(f"Error: {str(e)}")

# Footer
st.markdown("---")
st.markdown("Built with ❤️ using Streamlit, FastAPI, and MLflow")
PYEOF

# Create systemd service for FastAPI
sudo cat > /etc/systemd/system/fastapi.service <<EOF
[Unit]
Description=FastAPI Model Serving
After=network.target

[Service]
Type=simple
User=opc
WorkingDirectory=$APP_DIR
EnvironmentFile=/home/opc/app.env
ExecStart=/usr/local/bin/uvicorn main:app --host 0.0.0.0 --port ${fastapi_port}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create systemd service for Streamlit
sudo cat > /etc/systemd/system/streamlit.service <<EOF
[Unit]
Description=Streamlit Dashboard
After=network.target

[Service]
Type=simple
User=opc
WorkingDirectory=$APP_DIR
EnvironmentFile=/home/opc/app.env
ExecStart=/usr/local/bin/streamlit run streamlit_app.py --server.port ${streamlit_port} --server.address 0.0.0.0
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start services
echo "Starting FastAPI and Streamlit services..."
sudo systemctl daemon-reload
sudo systemctl enable fastapi.service
sudo systemctl enable streamlit.service
sudo systemctl start fastapi.service
sudo systemctl start streamlit.service

# Wait for services to start
echo "Waiting for services to start..."
sleep 10

# Check services status
if sudo systemctl is-active --quiet fastapi.service && \
   sudo systemctl is-active --quiet streamlit.service; then
    echo "=========================================="
    echo "API/Streamlit installation completed successfully!"
    echo "FastAPI URL: http://$(hostname -I | awk '{print $1}'):${fastapi_port}"
    echo "Streamlit URL: http://$(hostname -I | awk '{print $1}'):${streamlit_port}"
    echo "=========================================="
else
    echo "ERROR: Services failed to start"
    sudo journalctl -u fastapi.service -n 50
    sudo journalctl -u streamlit.service -n 50
    exit 1
fi

echo "API/Streamlit setup completed!"
