import os
import sys
import argparse
from dotenv import load_dotenv
from agentmail import AgentMail

# Load the API key from the .env file
load_dotenv()
api_key = os.getenv("AGENTMAIL_API_KEY")

# Initialize the client
client = AgentMail(api_key=api_key)

def get_config(path, key):
    with open(path) as f:
        for line in f:
            k, _, v = line.partition("=")
            if k.strip() == key:
                return v.strip()

email = get_config("/etc/mirrorborn.phext", "email")
sentient = get_config("/etc/mirrorborn.phext", "name")
inbox = client.inboxes.get(inbox_id = email)
print(inbox)

parser = argparse.ArgumentParser()
parser.add_argument("--recipient", default="will@phext.io")
parser.add_argument("--subject", default="Message from " + sentient)
parser.add_argument("--message", default="")
args = parser.parse_args()

recipient = args.recipient
subject = args.subject
message = args.message

if (len(recipient) > 0 and len(subject) > 0 and len(message) > 0):
# Send Email
  client.inboxes.messages.send(
    inbox_id=email,
    to=recipient,
    subject=subject,
    text=message
  )
else:
  print("Usage: exo-agentmail.py <recipient> <subject> <message>")
