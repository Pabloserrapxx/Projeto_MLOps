#!/bin/bash
# FastAPI + Streamlit consolidated initialization script

set -e

echo "Starting FastAPI + Streamlit installation..."

# Install required packages (skipping yum update to avoid OOM on Micro instances)
sudo yum install -y python3 python3-pip git

# Clone application code (adjust this to your actual repo if needed)
sudo mkdir -p /opt/mlops-app
sudo chown opc:opc /opt/mlops-app
cd /opt/mlops-app

# Install Python packages
sudo pip3 install fastapi==0.109.0 uvicorn==0.27.0 streamlit==1.31.0 requests==2.31.0 pandas numpy scikit-learn

# Create FastAPI app
cat <<'EOF' > /opt/mlops-app/api.py
from fastapi import FastAPI
from pydantic import BaseModel
import uvicorn

app = FastAPI(title="MLOps OCI API")

class PredictionInput(BaseModel):
    sepal_length: float
    sepal_width: float
    petal_length: float
    petal_width: float

@app.get("/")
def read_root():
    return {"status": "healthy", "message": "MLOps API is running"}

@app.post("/predict")
def predict(input_data: PredictionInput):
    # Mock prediction - replace with actual model loading from MLflow
    if input_data.petal_width < 0.8:
        return {"prediction": "Setosa", "probability": 0.99}
    elif input_data.petal_width < 1.75:
        return {"prediction": "Versicolor", "probability": 0.95}
    else:
        return {"prediction": "Virginica", "probability": 0.92}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=${fastapi_port})
EOF

# Create Streamlit app
cat <<'EOF' > /opt/mlops-app/streamlit_app.py
import streamlit as st
import requests
import os

BACKEND_URL = os.getenv("BACKEND_URL", "http://localhost:${fastapi_port}")

st.set_page_config(page_title="MLOps OCI - Iris Predictor", page_icon="🌸")
st.title("🌸 Iris Species Predictor")

with st.form("prediction_form"):
    st.subheader("Input Measurements")
    col1, col2 = st.columns(2)
    
    with col1:
        sepal_length = st.slider("Sepal Length (cm)", 4.0, 8.0, 5.8)
        sepal_width = st.slider("Sepal Width (cm)", 2.0, 4.5, 3.0)
    with col2:
        petal_length = st.slider("Petal Length (cm)", 1.0, 7.0, 4.35)
        petal_width = st.slider("Petal Width (cm)", 0.1, 2.5, 1.3)
    
    submit = st.form_submit_button("Predict")

if submit:
    payload = {
        "sepal_length": sepal_length,
        "sepal_width": sepal_width,
        "petal_length": petal_length,
        "petal_width": petal_width
    }
    
    try:
        response = requests.post(f"{BACKEND_URL}/predict", json=payload)
        if response.status_code == 200:
            result = response.json()
            st.success("Prediction Successful!")
            st.metric("Predicted Species", result["prediction"])
            st.progress(result["probability"], text=f"Confidence: {result['probability']:.2%}")
        else:
            st.error(f"Error: {response.status_code}")
    except Exception as e:
        st.error(f"Connection error: {str(e)}")
EOF

# Create systemd services
cat <<EOF | sudo tee /etc/systemd/system/fastapi.service
[Unit]
Description=FastAPI Server
After=network.target

[Service]
User=opc
WorkingDirectory=/opt/mlops-app
ExecStart=/usr/local/bin/python3 /opt/mlops-app/api.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF | sudo tee /etc/systemd/system/streamlit.service
[Unit]
Description=Streamlit App
After=network.target

[Service]
User=opc
WorkingDirectory=/opt/mlops-app
Environment=BACKEND_URL=http://localhost:${fastapi_port}
ExecStart=/usr/local/bin/streamlit run /opt/mlops-app/streamlit_app.py --server.port=${streamlit_port} --server.address=0.0.0.0
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Enable and start services
sudo systemctl daemon-reload
sudo systemctl enable fastapi streamlit
sudo systemctl start fastapi streamlit

# Configure firewall
sudo firewall-cmd --permanent --add-port=${fastapi_port}/tcp
sudo firewall-cmd --permanent --add-port=${streamlit_port}/tcp
sudo firewall-cmd --reload

echo "FastAPI + Streamlit installation completed!"
echo "FastAPI: http://$(hostname -I | awk '{print $1}'):${fastapi_port}"
echo "Streamlit: http://$(hostname -I | awk '{print $1}'):${streamlit_port}"
