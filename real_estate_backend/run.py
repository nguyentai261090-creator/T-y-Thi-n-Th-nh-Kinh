from dotenv import load_dotenv

load_dotenv()

from app import app  # noqa: E402

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000, debug=True)
