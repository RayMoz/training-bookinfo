from locust import HttpUser, task
from datetime import datetime
import random

class HelloWorldUser(HttpUser):
    @task
    def hello_world(self):

        # Get the current timestamp
        # current_timestamp = datetime.now()
        # waiter = str(random.randint(50, 100))

        # Format the timestamp as a string
        # timestamp_string = "Hello again - Time:" + current_timestamp.strftime("%Y-%m-%d %H:%M:%S")
        self.client.get("/productpage?u=normal")
        self.client.get("/productpage?u=test")
        self.client.get("/")
