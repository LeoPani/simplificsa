from fastapi import FastAPI

app = FastAPI(title="SimplifiCSA API")

@app.get("/")
def read_root():
    return {"status": "online", "message": "Backend do calendário rodando perfeito!"}
