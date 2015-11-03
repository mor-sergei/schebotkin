#!/usr/bin/python

import requests
import json
import argparse
import os
import logging
import ConfigParser

def OS_login(username, password, tenant,keystone):
    #Logs into provided Openstack with provided auth details. Returns login object.
    auth = {'auth': {"tenantName": tenant, "passwordCredentials": {"username": username, "password": password}}}
    header = {'content-type': 'application/json'}
    try:
        r = requests.post(keystone + '/tokens', data=json.dumps(auth), headers=header,timeout=5)
        #print r.text
        r.raise_for_status()
    except requests.exceptions.RequestException as e:
        logging.log(level=logging.ERROR,msg="OS Login error: " + str(e))
        exit(1)
    respObj = json.loads(r.text)
    logging.log(level=logging.DEBUG,msg="Auth token is: " + respObj['access']['token']['id'])
    return respObj

def get_limits(URL,token,target,tenant=""):
    #Get limits for provided Openstack project.  Returns available quota.
    header = {'content-type': 'application/json', 'User-Agent': 'python-keystoneclient', 'X-Auth-Token': token}
    try:
        if target.upper() == 'NEUTRON':
            q = requests.get(URL+"v2.0/quotas/"+tenant,headers=header,timeout=5)
            q.raise_for_status()
            n = requests.get(URL+"v2.0/networks?tenant_id=",headers=header,timeout=5)
            n.raise_for_status()
            s = requests.get(URL+"v2.0/subnets?tenant_id="+tenant,headers=header,timeout=5)
            s.raise_for_status()
            sg = requests.get(URL+"v2.0/security-groups?tenant_id=",headers=header,timeout=5)
            sg.raise_for_status()
            sgr = requests.get(URL+"v2.0/security-group-rules?tenant_id=",headers=header,timeout=5)
            sgr.raise_for_status()
            r = requests.get(URL+"v2.0/routers?tenant_id=",headers=header,timeout=5)
            r.raise_for_status()
            f = requests.get(URL+"v2.0/floatingips?tenant_id=",headers=header,timeout=5)
            f.raise_for_status()

        else:
            r = requests.get(URL+"/limits", headers=header,timeout=5)
            #print r.text
            r.raise_for_status()
    except requests.exceptions.RequestException as e:
        logging.log(level=logging.ERROR,msg=target.upper()+ " limits error: " + str(e))
        exit(1)
    if target.upper() == 'NEUTRON':
        networks=json.loads(n.text)
        quota = json.loads(q.text)
        subnets = json.loads(s.text)
        secgroups = json.loads(sg.text)
        secgrouprules = json.loads(sgr.text)
        routers = json.loads(r.text)
        fips = json.loads(f.text)
    else:
        respObj = json.loads(r.text)

    if target.upper() == 'NOVA':
        absolute = respObj['limits']['absolute']
        limits = dict(availableRAM=absolute['maxTotalRAMSize']-absolute['totalRAMUsed'],
                    availableCPU=absolute['maxTotalCores']-absolute['totalCoresUsed'],
                    availableNovaFIPS=absolute['maxTotalFloatingIps']-absolute['totalFloatingIpsUsed'],
                    availableInstances=absolute['maxTotalInstances']-absolute['totalInstancesUsed'],
                    availableNovaSecGroups=absolute['maxSecurityGroups']-absolute['totalSecurityGroupsUsed'],
                      novaReliable=True)
    if target.upper() == 'CINDER':
        absolute = respObj['limits']['absolute']
        limits = dict(availableGB=absolute.get('maxTotalVolumeGigabytes',0)-absolute.get('totalGigabytesUsed',0),
                    availableSnapshots=absolute.get('maxTotalSnapshots',0)-absolute.get('totalSnapshotsUsed',0),
                    availableVolumes=absolute.get('maxTotalVolumes',0)-absolute.get('totalVolumesUsed',0),
                      cinderReliable=True)
        if absolute.get('totalVolumesUsed',0) == 0:
            logging.log(logging.WARN,msg='No totals found. Try other APIs for counts.')
            try:
                vol = requests.get(URL+'/volumes/detail', headers=header,timeout=60)
                vol.raise_for_status()
                snap = requests.get(URL+'/snapshots', headers=header,timeout=5)
                snap.raise_for_status()
            except requests.exceptions.RequestException as e:
                logging.log(level=logging.ERROR,msg=target.upper()+ " limits error: " + str(e))
                exit(1)
            volumes = json.loads(vol.text)
            snapshots = json.loads(snap.text)
            limits['availableSnapshots']=absolute.get('maxTotalSnapshots',0)-len(snapshots)
            limits['availableVolumes']=absolute.get('maxTotalVolumes',0)-len(volumes)
            totalGigabytesUsed = 0
            for volume in volumes.get('volumes'):
                totalGigabytesUsed += int(volume.get('size'))
            limits['availableGB']=absolute.get('maxTotalVolumeGigabytes',0)-totalGigabytesUsed

    if target.upper() == 'NEUTRON':
        availableNetworks=len(networks['networks'])
        limits=dict(availableNetworks=quota['quota']['network']-len(networks['networks']),
                    availableSubnets=quota['quota']['subnet']-len(subnets['subnets']),
                    availableSecGroups=quota['quota']['security_group']-len(secgroups['security_groups']),
                    availableSecGroupRules=quota['quota']['security_group_rule']-len(secgrouprules['security_group_rules']),
                    availableRouters=quota['quota']['router']-len(routers['routers']),
                    availableFIPS=quota['quota']['floatingip']-len(fips['floatingips']),
                    neutronReliable=True
                    )

    return limits


def get_URL(respObj, target):
    url = ""
    for service in respObj['access']['serviceCatalog']:
        if service['name'] == target:
            url = service['endpoints'][0]['publicURL']
    #Check alternate names in case on old Metapod
    if url == "":
        if target.upper() == 'NOVA':
            url = get_URL(respObj,'Compute Service')
        if target.upper() == 'CINDER':
            url = get_URL(respObj,'Volume Service')
        if target.upper() == 'GLANCE':
            url = get_URL(respObj,'Image Service')
    return url

def gatherEnvs():
    #Looks for all expected environment variables. Returns a map of variables.
    envVars= dict(OS_USERNAME=os.getenv('DEP_CONFIGURATION_0_SPEC_PROVIDER_0_SPEC_AUTH_USERNAME',""),
                  OS_PASSWORD=os.getenv('DEP_CONFIGURATION_0_SPEC_PROVIDER_0_SPEC_AUTH_PASSWORD',""),
                  OS_KEYSTONEURL=os.getenv('DEP_CONFIGURATION_0_SPEC_PROVIDER_0_SPEC_AUTH_KEYSTONEURL',""),
                  OS_TENANTNAME=os.getenv('DEP_CONFIGURATION_0_SPEC_PROVIDER_0_SPEC_AUTH_TENANTNAME',""),
                  OS_TENANTID=os.getenv('DEP_CONFIGURATION_0_SPEC_PROVIDER_0_SPEC_AUTH_TENANTID',"")
                  )
    return envVars

def checkEnvs(envVars):
    #Checks the environment variable list and returns error if any are missing
    #Expects an envVar map
    status = {"state": True, "msg":"PASS"}
    for k,v in envVars.items():
        if v == "":
            status['state'] = False
            status['msg'] =  k + " is missing"
    return status

def flavorToRequirements(URL,token,flavor):
    header = {'content-type': 'application/json', 'User-Agent': 'python-keystoneclient', 'X-Auth-Token': token}
    try:
        r = requests.get(URL+'/flavors',headers=header,timeout=5)
        r.raise_for_status()
        flavorlist = json.loads(r.text)
        flid = ""
        for fl in flavorlist.get('flavors'):
            if fl.get('name') == flavor:
                flid = fl.get('id')
        if flid == "":
            logging.log(logging.ERROR,msg="Flavor "+flavor+" not found in target environment.")
            exit(1)
        r = requests.get(URL+'/flavors/'+flid,headers=header,timeout=5)
        r.raise_for_status()
    except requests.exceptions.RequestException as e:
        logging.log(level=logging.ERROR,msg="Requirements error: " + str(e))
        exit(1)

    flavor_obj=json.loads(r.text)
    required=dict(cpu=flavor_obj['flavor']['vcpus'],
                  ram=flavor_obj['flavor']['ram'],
                  disk=flavor_obj['flavor']['disk'])
    logging.log(level=logging.DEBUG,msg="Flavor "+flavor+" requires:\n"+json.dumps(required,indent=2,sort_keys=True))
    return required

def checkLimits(limits,requirements):
    #Check the Current Limits against provided requirements
    remaining = {}
    remaining['cpu']=limits.get('availableCPU')-requirements.get('cpu')
    remaining['ram']=limits.get('availableRAM')-requirements.get('ram')
    remaining['disk']=limits.get('availableGB')-requirements.get('disk')
    remaining['FIP']=limits.get('availableFIPS')-requirements.get('FIP')
    remaining['network']=limits.get('availableNetworks')-requirements.get('network')
    remaining['subnet']=limits.get('availableSubnets')-requirements.get('subnet')
    remaining['instances']=limits.get('availableInstances')-requirements.get('instances')
    remaining['secgroups']=limits.get('availableSecGroups')-requirements.get('secGroups')
    remaining['secgrouprules']=limits.get('availableSecGroupRules')-requirements.get('secGroupRules')
    remaining['volumes']=limits.get('availableVolumes')-requirements.get('volumes')
    logging.log(level=logging.DEBUG,msg="Limits remaining after deploy: \n" + json.dumps(remaining,indent=2,sort_keys=True))
    for k,v in remaining.items():
        if v < 0:
            logging.log(level=logging.ERROR,msg="Not enough "+str(k)+ " available for deploy")
            return False
    return True

def checkImage(URL,token,image):
    header = {'content-type': 'application/json', 'User-Agent': 'python-keystoneclient', 'X-Auth-Token': token}
    try:
        if URL.find('/v1/') > -1:
            r=requests.get(URL+'/images',headers=header,timeout=5)
            r.raise_for_status()
        else:
            r=requests.get(URL+'/v2/images',headers=header,timeout=5)
            r.raise_for_status()
    except requests.exceptions.RequestException as e:
        logging.log(level=logging.ERROR,msg="Image check error: " + str(e))
        exit(1)
    images = json.loads(r.text)
    found = False
    for i in images.get('images'):
        if i.get('name') == image:
            found = True
    return found


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("-l","--loglevel",type=int,choices=[1,2,3,4,5],help="Set loglevel. Expects integer 1 - 5. 1 being most granular.",default=1)
    parser.add_argument("-c","--config",type=str,help="Path to config file.",default="./pre-deploy/pre-deploy.conf")
    args=parser.parse_args()
    logging.basicConfig(format='%(asctime)s %(levelname)s: %(message)s',level=args.loglevel*10)
    #Validate presence of config and import it
    try:
        with open(args.config) as file:
            pass
    except IOError as e:
        logging.log(logging.ERROR,msg="Unable to access config file")
        exit(1)
    config = ConfigParser.RawConfigParser()
    config.read(args.config)

    envVars = gatherEnvs()
    envStatus = checkEnvs(envVars)

    if not envStatus['state']:
        logging.log(level=logging.ERROR,msg=envStatus['msg'])
        exit(1)
    else:
        logging.log(level=logging.INFO,msg="Environment variables successfully parsed.")

    logging.log(level=logging.DEBUG,msg="Attempting to login to OS.")
    oslogin = OS_login(envVars['OS_USERNAME'],envVars['OS_PASSWORD'],envVars['OS_TENANTNAME'],envVars['OS_KEYSTONEURL'])
    novaURL = get_URL(oslogin,'nova')
    logging.log(level=logging.DEBUG,msg="Nova URL is: " + novaURL)
    cinderURL = get_URL(oslogin,'cinder')
    logging.log(level=logging.DEBUG,msg="Cinder URL is: " + cinderURL)
    neutronURL = get_URL(oslogin,'neutron')
    logging.log(level=logging.DEBUG,msg="Neutron URL is: " + neutronURL)
    glanceURL= get_URL(oslogin,'glance')
    logging.log(level=logging.DEBUG,msg="Glance URL is: " + glanceURL)
    osNovalimits = get_limits(novaURL,oslogin['access']['token']['id'],'nova')
    osCinderlimits = get_limits(cinderURL,oslogin['access']['token']['id'],'cinder')
    # Check for Neutron.  If not present populate with Nova and fake data.
    if neutronURL == "":
        logging.log(logging.WARN,msg="Neutron not available defaulting to Nova net for limits")
        osNeutronlimits=dict(availableNetworks=999,
                    availableSubnets=999,
                    availableSecGroups=osNovalimits.get('availableNovaSecGroups'),
                    availableSecGroupRules=999,
                    availableRouters=999,
                    availableFIPS=osNovalimits.get('availableNovaFIPS'),
                    neutronReliable=False
                    )
    else:
        osNeutronlimits = get_limits(neutronURL,oslogin['access']['token']['id'],'neutron',envVars['OS_TENANTID'])
    allLimits = osNovalimits
    allLimits.update(osNeutronlimits)
    allLimits.update(osCinderlimits)
    logging.log(level=logging.DEBUG,msg="Current Limits:\n"+json.dumps(allLimits,indent=3,sort_keys=True))
    #Set Total requirments based on provided config and Deployment
    totalrequirments= {'cpu': 0, 'ram': 0, 'instances': 0, 'disk': 0, 'FIP': 0,
                       'volumes': config.getint('requirements', 'volumes'),
                       'network': config.getint('requirements', 'network'),
                       'router': config.getint('requirements', 'router'),
                       'subnet': config.getint('requirements', 'subnet'),
                       'secGroups': config.getint('requirements', 'security-groups'),
                       'secGroupRules': config.getint('requirements', 'security-group-rules')}
    for k,v in os.environ.items():
        if k.find('FLAVOR') > -1:
            instanceCount = os.environ.get(k[0:(len(k)-6)]+'COUNT')
            tmpreq=flavorToRequirements(novaURL,oslogin['access']['token']['id'],v)
            totalrequirments['cpu'] += int(tmpreq.get('cpu')) * int(instanceCount)
            totalrequirments['ram'] += int(tmpreq.get('ram')) * int(instanceCount)
            totalrequirments['disk'] += int(tmpreq.get('disk')) * int(instanceCount)
            totalrequirments['FIP'] += int(instanceCount)
            totalrequirments['instances'] += int(instanceCount)
            totalrequirments['volumes'] += int(instanceCount)
    logging.log(level=logging.DEBUG,msg="Total requirements: \n"+ json.dumps(totalrequirments,indent=2,sort_keys=True))
    logging.log(level=logging.DEBUG,msg="Checking for images")
    for k,v in os.environ.items():
        if k.find('IMAGE') > -1:
            if not checkImage(glanceURL,oslogin['access']['token']['id'],v):
                logging.log(level=logging.ERROR,msg="Image " + v + ' not found')
                exit(1)

    if checkLimits(allLimits,totalrequirments):
        if allLimits.get('novaReliable') and allLimits.get('neutronReliable') and allLimits.get('cinderReliable'):
            logging.log(level=logging.INFO,msg='SUCCESS Pre-deploy checks passed.')
        else:
            logging.log(level=logging.WARN,msg='SUCCESS Pre-deploy checks passed with warnings!')
        exit(0)
    else:
        logging.log(level=logging.INFO,msg='FAIL Pre-deploy checks have failed')
        exit(1)




if __name__== '__main__':
    main()
