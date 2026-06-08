from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
import socket
import time
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from starlette.responses import Response
from app import database

# Initialize database
database.Base.metadata.create_all(bind=database.engine)

app = FastAPI(title="Cloud-Native Task API")

# Prometheus Metrics
REQUEST_COUNT = Counter("http_requests_total", "Total HTTP Requests")
DB_LATENCY = Histogram("db_latency_seconds", "Time spent communicating with RDS")


def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()


@app.get("/")
def read_root():
    REQUEST_COUNT.inc()
    return {
        "message": "Cloud-Native API is Online",
        "container_id": socket.gethostname(),
        "ip_address": socket.gethostbyname(socket.gethostname()),
    }


@app.get("/tasks")
def get_tasks(db: Session = Depends(get_db)):
    start_time = time.time()
    tasks = db.query(database.Task).all()
    DB_LATENCY.observe(time.time() - start_time)
    return tasks


@app.post("/tasks")
def create_task(title: str, db: Session = Depends(get_db)):
    new_task = database.Task(title=title)
    db.add(new_task)
    db.commit()
    return {"status": "Task Created", "task": title}


@app.get("/health")
def health_check():
    return {"status": "healthy"}


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
