#! /usr/bin/python
# This script can be used to make callbacks to the Falcon Deployment API
# Assumes the presence of an FCN_DEP_DATA, FCN_API_URL, FCN_API_USERNAME, FCN_API_PASSWORD env var as validated by envhelper.py
# Usage: callbacks.py [--stage STAGE] [--status STATUS] [--data DATA] [--statefile STATE] [-l | --loglevel LOGLEVEL] [--no-api]
# where:
#  STAGE = The name of the deployment stage being reported must be set with a status e.g. pre-deploy
#  STATUS = The status being reported.  One of PENDING, SUCCESS, FAILURE must be set with a stage
#  DATA = Optional status details.  E.g. Failure message.
#  STATE = path to a file containing the environment deployment details in valid json format.  E.g. terraform.tfstate.
#  LOGLEVEL = Set loglevel. Expects integer 1 - 5. 1 being most granular


from sys import exit
from datetime import datetime
import json,os,argparse,requests,logging

def submitStatus(apiURL,username,password,msg):
    # Submit a status message to the API
    try:
        r = requests.put(apiURL,data=msg,auth=(username,password))
        r.raise_for_status()
    except requests.exceptions.RequestException as e:
        print "Submission failure: " + str(e)
        exit(1)



def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage",type=str,help="The name of the deployment stage being reported",default='')
    parser.add_argument("--status",type=str,help="The status being reported",choices=['PENDING','SUCCESS','FAILURE',''],default='')
    parser.add_argument("--data", type=str, help="Optional status details")
    parser.add_argument("--state", type=str, help="Path to file containing deployed environment details JSON",default='')
    parser.add_argument("-l","--loglevel",type=int,choices=[1,2,3,4,5],help="Set loglevel. Expects integer 1 - 5. 1 being most granular.",default=1)
    parser.add_argument("--no-api", dest='noapi', help="Disable send to API for testing", action='store_true')
    args = parser.parse_args()
    # Set logging configuration
    logging.basicConfig(format='%(asctime)s %(levelname)s: %(message)s',level=args.loglevel*10)

    #Check that stage is passed with status
    if args.stage != "":
        if args.status =="":
            logging.log(logging.ERROR,msg="Stage cannot be set without status")
            exit(1)
    if args.status != "":
        if args.stage == "":
            logging.log(logging.ERROR,msg="Status cannot be set without stage")
            exit(1)
    if args.stage =="" and args.state =="":
        logging.log(logging.ERROR,msg="Must have update to send.")
        exit(1)

    # Grab the deployment JSON from the file prepped by envhelper
    try:
        with open('/.private/deployment.json') as file:
            pass
    except IOError as e:
        logging.log(logging.ERROR,msg="Unable to access deployment file")
        exit(1)
    deployment=json.loads(open('/.private/deployment.json').read())


    # Append state if provided
    if args.state != "":
        try:
            with open(args.state) as file:
                pass
        except IOError as e:
            logging.log(logging.ERROR,msg="Unable to access target state file")
            exit(1)
        statefile=open(args.state).read()
        statedata=json.loads(statefile)
        deployment['state']=statedata

    # If the stage exists grab started time if it does
    starttime = ""
    exist=False
    index=0
    for event in deployment['status']:
        if event['stage'] == args.stage:
            starttime = event['started']
            exist=True
        index+=1


    # Append status if provided

    if args.status == "PENDING":
        statusmsg = dict(stage=args.stage,
                         started=str(datetime.utcnow()),
                         completed="",
                         status="PENDING",
                         details=args.data
                         )
    else:
        if args.status == "SUCCESS" or args.status == 'FAILURE':
            statusmsg = dict(stage=args.stage,
                             started=starttime,
                             completed=str(datetime.utcnow()),
                             status=args.status,
                             details=args.data
                            )
        else:
            statusmsg = {}

    if statusmsg != {}:
        if exist:
            logging.log(logging.DEBUG,msg='Updating existing status.')
            deployment['status'][index-1] = statusmsg
        else:
            logging.log(logging.DEBUG,msg='Adding new status')
            deployment['status'].append(statusmsg)

    logging.log(logging.DEBUG,msg='Submitting update to API')
    if not args.noapi:
        submitStatus(os.getenv('FCN_API_URL'),os.getenv('FCN_API_USERNAME'),os.getenv('FCN_API_PASSWORD'),json.dumps(deployment))
    else:
        logging.log(logging.INFO,msg="No API mode selected. Would have sent: \n" + json.dumps(deployment,indent=2,sort_keys=True))
    # Write out updated deployment json for callbacks to use
    try:
        with open('/.private/deployment.json','w') as content_file:
            content_file.write(json.dumps(deployment))
    except IOError as e:
        logging.log(logging.ERROR,msg='Unable to write deployment file: ' + str(e))
        os.exit(1)

if __name__== '__main__':
    main()