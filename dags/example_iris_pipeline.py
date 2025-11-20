from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta
import mlflow
import mlflow.sklearn
from sklearn.datasets import load_iris
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score
import os

# MLflow configuration
MLFLOW_TRACKING_URI = os.getenv("MLFLOW_TRACKING_URI", "http://localhost:5000")
mlflow.set_tracking_uri(MLFLOW_TRACKING_URI)

# Default arguments for the DAG
default_args = {
    'owner': 'mlops-team',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

def load_data():
    """Load and prepare the Iris dataset"""
    print("Loading Iris dataset...")
    iris = load_iris()
    X_train, X_test, y_train, y_test = train_test_split(
        iris.data, iris.target, test_size=0.2, random_state=42
    )
    
    # Save data for next tasks (in production, use a proper storage)
    import pickle
    with open('/tmp/train_data.pkl', 'wb') as f:
        pickle.dump((X_train, y_train), f)
    with open('/tmp/test_data.pkl', 'wb') as f:
        pickle.dump((X_test, y_test), f)
    
    print(f"Data loaded: {X_train.shape[0]} training samples, {X_test.shape[0]} test samples")
    return "Data loaded successfully"

def train_model():
    """Train a Random Forest model"""
    print("Training model...")
    
    # Load data
    import pickle
    with open('/tmp/train_data.pkl', 'rb') as f:
        X_train, y_train = pickle.load(f)
    
    # Start MLflow run
    mlflow.set_experiment("iris-classification")
    
    with mlflow.start_run(run_name="random_forest_training"):
        # Model parameters
        n_estimators = 100
        max_depth = 10
        
        # Log parameters
        mlflow.log_param("n_estimators", n_estimators)
        mlflow.log_param("max_depth", max_depth)
        mlflow.log_param("dataset", "iris")
        
        # Train model
        model = RandomForestClassifier(
            n_estimators=n_estimators,
            max_depth=max_depth,
            random_state=42
        )
        model.fit(X_train, y_train)
        
        # Save model
        mlflow.sklearn.log_model(model, "model")
        
        # Get run ID
        run_id = mlflow.active_run().info.run_id
        
        # Save run_id for next task
        with open('/tmp/run_id.txt', 'w') as f:
            f.write(run_id)
        
        print(f"Model trained successfully. Run ID: {run_id}")
    
    return f"Model trained with run_id: {run_id}"

def evaluate_model():
    """Evaluate the trained model"""
    print("Evaluating model...")
    
    # Load test data
    import pickle
    with open('/tmp/test_data.pkl', 'rb') as f:
        X_test, y_test = pickle.load(f)
    
    # Load run_id
    with open('/tmp/run_id.txt', 'r') as f:
        run_id = f.read().strip()
    
    # Continue the same run
    with mlflow.start_run(run_id=run_id):
        # Load model
        model_uri = f"runs:/{run_id}/model"
        model = mlflow.sklearn.load_model(model_uri)
        
        # Make predictions
        y_pred = model.predict(X_test)
        
        # Calculate metrics
        accuracy = accuracy_score(y_test, y_pred)
        precision = precision_score(y_test, y_pred, average='weighted')
        recall = recall_score(y_test, y_pred, average='weighted')
        f1 = f1_score(y_test, y_pred, average='weighted')
        
        # Log metrics
        mlflow.log_metric("accuracy", accuracy)
        mlflow.log_metric("precision", precision)
        mlflow.log_metric("recall", recall)
        mlflow.log_metric("f1_score", f1)
        
        print(f"Evaluation complete:")
        print(f"  Accuracy: {accuracy:.4f}")
        print(f"  Precision: {precision:.4f}")
        print(f"  Recall: {recall:.4f}")
        print(f"  F1-Score: {f1:.4f}")
        
        # Decision: register model if accuracy > 0.9
        if accuracy > 0.9:
            return "Model performance is good. Proceeding to registration."
        else:
            return "Model performance is below threshold. Skipping registration."

def register_model():
    """Register the model in MLflow Model Registry"""
    print("Registering model...")
    
    # Load run_id
    with open('/tmp/run_id.txt', 'r') as f:
        run_id = f.read().strip()
    
    # Register model
    model_uri = f"runs:/{run_id}/model"
    model_name = "iris-classifier"
    
    result = mlflow.register_model(model_uri, model_name)
    
    print(f"Model registered: {model_name}, version: {result.version}")
    
    # Transition to staging
    client = mlflow.tracking.MlflowClient()
    client.transition_model_version_stage(
        name=model_name,
        version=result.version,
        stage="Staging"
    )
    
    print(f"Model transitioned to Staging")
    return f"Model {model_name} v{result.version} registered and moved to Staging"

# Define the DAG
dag = DAG(
    'iris_ml_pipeline',
    default_args=default_args,
    description='Complete ML pipeline for Iris classification',
    schedule_interval=timedelta(days=1),  # Run daily
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=['ml', 'classification', 'iris', 'mlflow'],
)

# Define tasks
task_load_data = PythonOperator(
    task_id='load_data',
    python_callable=load_data,
    dag=dag,
)

task_train_model = PythonOperator(
    task_id='train_model',
    python_callable=train_model,
    dag=dag,
)

task_evaluate_model = PythonOperator(
    task_id='evaluate_model',
    python_callable=evaluate_model,
    dag=dag,
)

task_register_model = PythonOperator(
    task_id='register_model',
    python_callable=register_model,
    dag=dag,
)

# Define task dependencies
task_load_data >> task_train_model >> task_evaluate_model >> task_register_model
