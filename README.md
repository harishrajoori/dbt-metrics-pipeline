# DBT Metrics Layer

![Build Status](https://img.shields.io/badge/build-passing-brightgreen)
![Python](https://img.shields.io/badge/python-3.8%2B-blue)
![Spark](https://img.shields.io/badge/spark-3.0%2B-orange)
![AWS](https://img.shields.io/badge/aws-s3%20|%20mwaa-yellow)
![Airflow](https://img.shields.io/badge/airflow-2.0%2B-blue)

A comprehensive data engineering framework designed to orchestrate complex data pipelines, manage semantic layers, and ensure data quality at scale. This project serves as a foundational layer for generating critical business insights across various domains including revenue, customer behavior, and operational metrics.

## 🚀 Key Features

*   **Modular Architecture:** Organized by domain (Bi, WBR, TPS, PAYG) for scalability and maintainability.
*   **Metric Standardization:**  Centralized definitions for key business metrics to ensure consistency across reporting.
*   **Automated Orchestration:** robust Airflow DAGs for reliable data processing and dependency management.
*   **Infrastructure as Code:**  Integration with AWS services (S3, MWAA) managed via automated deployment pipelines.
*   **Data Quality & Testing:**  Integrated data validation steps within the pipeline to ensure high data integrity.

## 🛠 Tech Stack

*   **Core:** Python, SQL
*   **Orchestration:** Apache Airflow (MWAA)
*   **Data Processing:** Spark, DBT (Data Build Tool)
*   **Infrastructure:** AWS (S3, Lambda, EventBridge), Docker
*   **CI/CD:** Jenkins, GitHub Actions

## 📂 Project Structure

```
data-pipeline-framework/
├── airflow_dags/       # Airflow DAG definitions for improved orchestration
├── metrics_dbt/        # DBT models and configurations for data transformation
├── docker/             # Docker configurations for local development
├── scripts/            # Utility scripts for automation and maintenance
└── ...
```

## ⚡️ Local Setup & Testing

1.  **Prerequisites:**
    *   Docker & Docker Compose
    *   Python 3.8+
    *   AWS CLI configured (for mocked AWS services)

2.  **Installation:**

    ```bash
    git clone https://github.com/my-username/data-pipeline-framework.git
    cd data-pipeline-framework
    pip install -r requirements.txt
    ```

3.  **Running Locally:**

    Start the local Airflow environment using Docker:

    ```bash
    ./mwaa-local-env start
    ```

    Access the Airflow UI at `http://localhost:8080`.

4.  **Running Tests:**

    Execute the unit test suite:

    ```bash
    pytest tests/
    ```

## 🤝 Contributing

Contributions are welcome! Please feel free to verify the `CONTRIBUTING.md` (if available) or submit a Pull Request.

