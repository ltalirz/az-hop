from flask import Flask, request, redirect
MyApp = Flask(__name__)

@MyApp.route("/")
def index():
    return redirect(request.host_url+"rnode/grafana/3000/")

if __name__ == "__main__":
    MyApp.run()
