#! /usr/bin/python
# This script creates a deployment environment to be consumed by the targeted script.
# Usage: envhelper.py  -t TARGET  [-l | --loglevel LOGLEVEL] [--use-vault]
#   TARGET is the targeted deployment script.
#   LOGLEVEL Set loglevel. Expects integer 1 - 5. 1 being most granular.
#   use-vault flags whether or not to retrieve secrets from Vault

#Todo: Add validation code.

from sys import exit
import json,os,argparse,logging,hvac
from Crypto.PublicKey import RSA


def gatherEnvs(vault=False):
    #Looks for all expected environment variables. Returns a map of variables.
    envVars={}
    envVars['FCN_API_URL'] = os.getenv('FCN_API_URL',"")
    envVars['FCN_DEP_DATA'] = os.getenv('FCN_DEP_DATA',"")
    envVars['FCN_API_USERNAME'] = os.getenv('FCN_API_USERNAME',"")
    if vault:
        envVars['FCN_VAULT_URL'] = os.getenv('FCN_VAULT_URL',"")
        envVars['FCN_VAULT_TOKEN'] = os.getenv('FCN_VAULT_TOKEN',"")
    return envVars

def checkEnvs(envVars):
    #Checks the environment variable list and returns error if any are missing
    #Expects an envVar map
    status = {"state": True, "msg":"PASS"}
    for k,v in envVars.items():
        if v == "":
            status['state'] = False
            status['msg'] = "FAIL: " + k + " is missing"
    return status

def validateDepData(depData):
    #Checks provided deployment data against deployment schema.
    #Returns status
    status = {"state": True, "msg":"PASS"}

    # ... some validation code here

    return status

def getVaultSecret(secretKey,vaultURL,vaultToken):
    client = hvac.Client(url=vaultURL,token=vaultToken)
    secret = client.read('secret/'+secretKey)
    if secret == None:
        logging.log(logging.ERROR,msg='Secret '+secretKey+' not found')
        return ""
    secret = secret.get('data',"")
    if secret == "":
        logging.log(logging.ERROR,msg='Secret '+secretKey+' not found')
        return ""
    else:
        return secret.get('value',"")


def walk(node,parent_key):
    if isinstance(node,dict):
        for key, value in node.items():
            if isinstance(value,dict):
                walk(value,parent_key+key+"_")
            else:
                if isinstance(value,list):
                    x = 0
                    for v in value:
                        walk(v,parent_key+str(x)+"_"+key+"_")
                        x+=1
                index = parent_key + key
                os.environ[index.upper()] = str(value)
    else:
        os.environ[parent_key.upper()] = node

def generateKeypair():
    logging.log(logging.DEBUG,msg='Generating temporary keypair')
    key = RSA.generate(2048)
    try:
        with open('/.private/private.key','w') as content_file:
            os.chmod('/.private/private.key',0600)
            content_file.write(key.exportKey('PEM'))
        pubkey = key.publickey()
        with open('/.private/public.key','w') as content_file:
            content_file.write(pubkey.exportKey('OpenSSH'))
    except IOError as e:
        logging.log(logging.ERROR,msg='Unable to access keyfiles: ' + str(e))
        os.exit(1)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("-t","--target",type=str,help="Target script to spawn post launch",required=True)
    parser.add_argument("-l","--loglevel",type=int,choices=[1,2,3,4,5],help="Set loglevel. Expects integer 1 - 5. 1 being most granular.",default=1)
    parser.add_argument("--use-vault",dest="vault", help="Enable Vault for secret storage", action='store_true')
    args = parser.parse_args()
    #Set Logging config
    logging.basicConfig(format='%(asctime)s %(levelname)s: %(message)s',level=args.loglevel*10)

    #Validate presence of target script
    try:
        with open(args.target) as file:
            pass
    except IOError as e:
        logging.log(logging.ERROR,msg="Unable to access target script")
        exit(1)

    #Gather and check expected env variables
    envVars = gatherEnvs(args.vault)
    envStatus = checkEnvs(envVars)
    if not envStatus['state']:
        logging.log(logging.ERROR,msg=envStatus['msg'])
        exit(1)

    #Validate the deployment data
    deployment = json.loads(envVars['FCN_DEP_DATA'])
    depStatus = validateDepData(deployment)
    if not depStatus['state']:
        logging.log(logging.ERROR,msg=depStatus['msg'])
        exit(1)

    #Create environment variables from deployment data
    logging.log(logging.INFO,msg="Beggining deployment parse")
    walk(deployment,'DEP_')
    logging.log(logging.INFO,msg="Deployment parse complete")

    # Create a temporary keypair that can be used by target script
    generateKeypair()

    #Launch target script as child process such that environment is available

    logging.log(logging.INFO,msg="Calling target script: " + args.target)
    loggableEnv=json.dumps(os.environ.data,indent=3,sort_keys=True)
    if args.vault:
        os.environ['FCN_API_PASSWORD']=getVaultSecret(envVars['FCN_API_USERNAME'],envVars['FCN_VAULT_URL'],envVars['FCN_VAULT_TOKEN'])
        #Walk provided Dep JSON and gather other Secrects
        for k,v in os.environ.items():
            if v[0:6] == 'vault:':
                os.environ[k] = getVaultSecret(v[6:],envVars['FCN_VAULT_URL'],envVars['FCN_VAULT_TOKEN'])
    else:
        #Vault not selected check for API PWD in environment
        if os.environ.get('FCN_API_PASSWORD') == None:
            logging.log(logging.ERROR,msg="FCN_API_PASSWORD not set")
            exit(1)

    logging.log(logging.DEBUG,msg="My Environment is: \n" + loggableEnv)

    # Write out deployment json for callbacks to use
    try:
        with open('/.private/deployment.json','w') as content_file:
            content_file.write(envVars.get('FCN_DEP_DATA'))
    except IOError as e:
        logging.log(logging.ERROR,msg='Unable to write deployment file: ' + str(e))
        os.exit(1)

    os.system(args.target)



if __name__== '__main__':
    main()