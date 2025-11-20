import streamlit as st
import requests
import os

# Configuration
# Try to get the backend URL from environment variable, default to localhost
BACKEND_URL = os.getenv("BACKEND_URL", "http://localhost:8000")

st.set_page_config(
    page_title="MLOps OCI - Iris Predictor",
    page_icon="🌸",
    layout="centered"
)

st.title("🌸 Iris Species Predictor")
st.markdown(f"Connected to Backend: `{BACKEND_URL}`")

st.write("""
This application predicts the Iris flower species based on its measurements.
It demonstrates a full MLOps pipeline running on Oracle Cloud Infrastructure (OCI).
""")

# Input Form
with st.form("prediction_form"):
    st.subheader("Input Measurements")
    
    col1, col2 = st.columns(2)
    
    with col1:
        sepal_length = st.slider("Sepal Length (cm)", 4.0, 8.0, 5.8)
        sepal_width = st.slider("Sepal Width (cm)", 2.0, 4.5, 3.0)
        
    with col2:
        petal_length = st.slider("Petal Length (cm)", 1.0, 7.0, 4.35)
        petal_width = st.slider("Petal Width (cm)", 0.1, 2.5, 1.3)
        
    submit_button = st.form_submit_button("Predict Species")

if submit_button:
    # Prepare payload
    payload = {
        "sepal_length": sepal_length,
        "sepal_width": sepal_width,
        "petal_length": petal_length,
        "petal_width": petal_width
    }
    
    with st.spinner("Calling API..."):
        try:
            response = requests.post(f"{BACKEND_URL}/predict", json=payload)
            
            if response.status_code == 200:
                result = response.json()
                prediction = result["prediction"]
                probability = result["probability"]
                
                st.success("Prediction Successful!")
                
                # Display Result
                st.metric(label="Predicted Species", value=prediction)
                st.progress(probability, text=f"Confidence: {probability:.2%}")
                
                # Visual feedback based on species
                if prediction == "Setosa":
                    st.image("https://upload.wikimedia.org/wikipedia/commons/thumb/5/56/Kosaciec_szczecinkowaty_Iris_setosa.jpg/320px-Kosaciec_szczecinkowaty_Iris_setosa.jpg", caption="Iris Setosa")
                elif prediction == "Versicolor":
                    st.image("https://upload.wikimedia.org/wikipedia/commons/thumb/4/41/Iris_versicolor_3.jpg/320px-Iris_versicolor_3.jpg", caption="Iris Versicolor")
                elif prediction == "Virginica":
                    st.image("https://upload.wikimedia.org/wikipedia/commons/thumb/9/9f/Iris_virginica.jpg/320px-Iris_virginica.jpg", caption="Iris Virginica")
                    
            else:
                st.error(f"Error: {response.status_code} - {response.text}")
                
        except requests.exceptions.ConnectionError:
            st.error(f"Failed to connect to backend at {BACKEND_URL}. Is it running?")
        except Exception as e:
            st.error(f"An error occurred: {str(e)}")

# Sidebar info
st.sidebar.header("About")
st.sidebar.info(
    """
    **Project:** MLOps on OCI
    **Stack:**
    - Infrastructure: Terraform (OCI)
    - Orchestration: Airflow
    - Tracking: MLflow
    - Serving: FastAPI
    - Frontend: Streamlit
    """
)
