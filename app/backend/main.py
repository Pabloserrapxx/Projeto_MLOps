from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn
import os
import pandas as pd
import numpy as np
# import mlflow.pyfunc # Uncomment when MLflow is connected

app = FastAPI(title="MLOps OCI Prediction API", version="1.0.0")

# --- Data Models ---
class IrisInput(BaseModel):
    sepal_length: float
    sepal_width: float
    petal_length: float
    petal_width: float

class PredictionOutput(BaseModel):
    prediction: str
    probability: float

# --- Mock Model (Replace with MLflow loading) ---
# In a real scenario, you would load the model from MLflow Artifacts
# model = mlflow.pyfunc.load_model("models:/IrisModel/Production")

def mock_predict(data):
    # Simple logic to simulate prediction based on Iris dataset rules
    # 0: Setosa, 1: Versicolor, 2: Virginica
    if data.petal_width < 0.8:
        return "Setosa", 0.99
    elif data.petal_width < 1.75:
        return "Versicolor", 0.95
    else:
        return "Virginica", 0.92

@app.get("/")
def read_root():
    return {"status": "healthy", "message": "MLOps OCI API is running"}

@app.post("/predict", response_model=PredictionOutput)
def predict(input_data: IrisInput):
    try:
        # Convert input to dataframe if needed by the model
        # df = pd.DataFrame([input_data.dict()])
        
        # prediction = model.predict(df)
        pred_class, prob = mock_predict(input_data)
        
        return PredictionOutput(prediction=pred_class, probability=prob)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
