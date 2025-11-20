document.getElementById('prediction-form').addEventListener('submit', function(event) {
    event.preventDefault();

    const sepalLength = document.getElementById('sepal-length').value;
    const sepalWidth = document.getElementById('sepal-width').value;
    const petalLength = document.getElementById('petal-length').value;
    const petalWidth = document.getElementById('petal-width').value;

    const data = {
        "data": [
            parseFloat(sepalLength),
            parseFloat(sepalWidth),
            parseFloat(petalLength),
            parseFloat(petalWidth)
        ]
    };

    fetch('http://127.0.0.1:5000/predict', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(data)
    })
    .then(response => response.json())
    .then(result => {
        const predictionResult = document.getElementById('prediction-result');
        if (result.prediction) {
            predictionResult.textContent = result.prediction;
        } else {
            predictionResult.textContent = 'Error: ' + (result.error || 'Unknown error');
        }
    })
    .catch(error => {
        const predictionResult = document.getElementById('prediction-result');
        predictionResult.textContent = 'Error: Could not connect to the server.';
        console.error('Error:', error);
    });
});
