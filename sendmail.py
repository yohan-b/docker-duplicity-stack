#!/usr/bin/env python
# -*- coding: utf-8 -*-

import smtplib

from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.application import MIMEApplication
import sys
import os
import json
from datetime import datetime
import logging
logging.basicConfig()
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("text_file", help="Please specify the file containing the message as plain text.")
parser.add_argument("credentials", help="Please specify the file containing the SMTP credentials as JSON text.")
parser.add_argument("-i", "--html_file", default=None, help="If needed, specify the file containing the message as HTML.")
parser.add_argument("-a", "--attachment", default=None, help="If needed, specify the attachment path.")

args = parser.parse_args()

with open(args.credentials) as json_file:
    data = json.load(json_file)
    user = data["user"]
    password = data["password"]
    sender = data["sender"]
    receiver = data["receiver"]

# Create message container - the correct MIME type is
# multipart/alternative or multipart/mixed if there are attachments.
if args.attachment is not None:
    msg = MIMEMultipart('mixed')
    text_msg = MIMEMultipart('alternative')
else:
    msg = MIMEMultipart('alternative')
msg['Subject'] = u"Secrets archive changed."
msg['From'] = sender
msg['To'] = receiver

with open(args.text_file, 'r') as file:
    text = file.read()
#text = u"Bonjour , \n \
#	Test."
part1 = MIMEText(text, 'plain', 'utf-8')
if args.attachment is not None:
    text_msg.attach(part1)
else:
    msg.attach(part1)
if args.html_file is not None:
    with open(args.html_file, 'r') as file:
        html = file.read()

#    html = u"""\
#	<html>
#	  <head></head>
#	  <body>
#	    <p>Bonjour,<br>
#	    </p>
#	    <p>Test
#	    </p>
#	  </body>
#	</html>
#	"""
    part2 = MIMEText(html, 'html', 'utf-8')
    if args.attachment is not None:
        text_msg.attach(part2)
    else:
        msg.attach(part2)

if args.attachment is not None:
    msg.attach(text_msg)
    with open(args.attachment, 'rb') as file:
        attachment = MIMEApplication(file.read(), 'octet-stream')
    attachment.add_header('Content-Disposition', 'attachment',
                        filename=os.path.basename(file.name))
    msg.attach(attachment)

# print msg.as_string().encode('ascii')
print "sending"
s = smtplib.SMTP('ssl0.ovh.net', 587)
s.set_debuglevel(1)
s.login(user, password)

# sendmail function takes 3 arguments: sender's address, recipient's address
# and message to send - here it is sent as one string.
s.sendmail(sender, receiver, msg.as_string().encode('ascii'))
s.quit()
