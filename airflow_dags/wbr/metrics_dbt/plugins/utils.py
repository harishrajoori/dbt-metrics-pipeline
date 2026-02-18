import boto3
import logging
import traceback

from airflow.models import Variable
from wbr.metrics_dbt.config import config as config
from tl_callbacks.pagerduty import pager_duty_incident_dag_failure
from tl_callbacks.slack_utils import AirflowInstance, message_builder, post_to_slack

log = logging.getLogger()

TC_ENV = Variable.get("TC_ENV")

def get_ssm_value(name):
    client = boto3.client('ssm', 'eu-west-1')
    response = client.get_parameter(Name=name)
    return response['Parameter']['Value']


def mece_dq_check_task_failure_callback(ctx, channel=config.WEBHOOK_CHANNEL, url_ssm_name=config.WEBHOOK_SMM_NAME):
    try:
        task_instance = ctx['ti']
        airflow_instance = AirflowInstance()

        # fetch webhook url from aws ssm parameter store 
        webhook_url=get_ssm_value(url_ssm_name)
    
        # create task failure message
        message = message_builder(airflow_instance, task_instance, 'failure', channel).to_dict()
    
        if TC_ENV.lower() == "data":
            # push failure notification to slack channel
            post_to_slack(message=message, webhook_url=webhook_url,)

            # raise a low priority pagerduty incident
            pager_duty_incident_dag_failure(context=ctx, urgency="low", team="bi")

    except Exception as e:
        error_trace = traceback.print_exc()
        log.info(f'\nError Occurred; Refer Stack-Trace Below ::')
        log.info(f'\n{str(error_trace)}')