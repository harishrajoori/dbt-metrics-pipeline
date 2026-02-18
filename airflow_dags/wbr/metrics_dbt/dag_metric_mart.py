import os
import json

from airflow import DAG
from cosmos import ProjectConfig, DbtTaskGroup
from airflow.sensors.external_task import ExternalTaskSensor
from airflow.operators.dummy import DummyOperator
from cosmos.config import RenderConfig, ProfileConfig
from airflow.operators.python import BranchPythonOperator
from datetime import datetime, timedelta

from airflow.utils.trigger_rule import TriggerRule
from cosmos.profiles import TrinoLDAPProfileMapping
from airflow.utils.task_group import TaskGroup
from wbr.metrics_dbt.config import config as config
import wbr.metrics_dbt.plugins.utils as utils


project_path = config.PROJECT_PATH


def choose_weekend_model(ds):
    try:
        date_obj = datetime.strptime(ds, '%Y-%m-%d')
        day_of_week = date_obj.strftime('%A')
        print(day_of_week)
        if day_of_week == 'Saturday':
            return [f'week_fytd.refresh_week_marts.{i}_mart.run' for i in config.MODELS_LIST]
        else:
            return 'skiped_tasked'
    except ValueError:
        return "Invalid date format. Please use YYYY-MM-DD."


profile_config = ProfileConfig(
    profile_name="analytics_framework_con",
    target_name=config.ENV,
    profile_mapping=TrinoLDAPProfileMapping(
        conn_id=config.CONN_ID,
        profile_args={
            "database": config.TARGET_DATABASE,
            "schema": config.TARGET_SCHEMA
            },
        disable_event_tracking=True
        )
)


def render_config(tag):
    render_config = RenderConfig(
            select=tag,  # intersection
            enable_mock_profile=False
            )
    return render_config


with DAG(
    dag_id="dag_metric_mart",
    max_active_runs=2,
    default_view='graph',
    schedule_interval="30 8 * * *",
    start_date=datetime.strptime('2024-9-25', "%Y-%m-%d"),
    catchup=True,
    concurrency=12,
    default_args={
        'owner': 'Analytics Engineering',
        'retries': 2,
        'on_failure_callback': utils.mece_dq_check_task_failure_callback}
    ):

    sensor_marketing = ExternalTaskSensor(
      task_id="sensor_mkt",
      external_dag_id=config.MKT_TBL,
      external_task_id=config.MKT_TBL_TASK_ID,
      mode='reschedule',
      timeout=43200,
      poll_interval=60,
      execution_delta=timedelta(hours=1),
      check_existence=True
      )

    sensor_marketing_evening = ExternalTaskSensor(
        task_id="sensor_mkt_evening",
        external_dag_id=config.MKT_TBL_EVNG,
        external_task_id=config.MKT_TBL_TASK_ID,
        mode='reschedule',
        timeout=64800,
        poll_interval=60,
        execution_delta=timedelta(hours=-10),
        check_existence=True
    )

    sensor_customer = ExternalTaskSensor(
      task_id="sensor_cust",
      external_dag_id=config.CUST_TBL,
      mode='reschedule',
      timeout=36000,
      execution_delta=timedelta(hours=4),
      poll_interval=60,
      check_existence=True
      )

    sensor_user_growth = ExternalTaskSensor(
      task_id="sensor_user",
      external_dag_id=config.USER_TBL,
      mode='reschedule',
      timeout=36000,
      poll_interval=60,
      check_existence=True
      )

    sensor_fm = ExternalTaskSensor(
      task_id="sensor_fm",
      external_dag_id=config.FM_TBL,
      mode='reschedule',
      execution_delta=timedelta(hours=8, minutes=30),
      timeout=36000,
      poll_interval=60,
      check_existence=True
      )

    dbt_day = DbtTaskGroup(
        group_id='refresh_day_marts',
        profile_config=profile_config,
        project_config=ProjectConfig(
            dbt_project_path=project_path,
            env_vars={
                "exe_start_date": '{{ ds }}',
                "exe_end_date": '{{ ds }}',
                "exe_type": 'day'
            }
        ),
        operator_args={
                "install_deps": True,  # install any necessary dependencies before running any dbt command
            },
        render_config=render_config(config.DATA_TAG)
    )

    branch = BranchPythonOperator(
        task_id='choose_weekend_model',
        python_callable=choose_weekend_model
    )

    with TaskGroup(group_id='week_fytd') as week_fytd:
        dbt_week = DbtTaskGroup(
            group_id='refresh_week_marts',
            profile_config=profile_config,
            project_config=ProjectConfig(
                dbt_project_path=project_path,
                env_vars={
                    "exe_start_date": '{{ macros.ds_add(ds, -6) }}',
                    "exe_end_date": '{{ ds }}',
                    "exe_type": 'week'
                }
            ),
            operator_args={
                    "install_deps": True,  # install any necessary dependencies before running any dbt command
                },
            render_config=render_config(config.DATA_TAG)
        )

        dbt_fytd = DbtTaskGroup(
            group_id='refresh_fytd_marts',
            profile_config=profile_config,
            project_config=ProjectConfig(
                dbt_project_path=project_path,
                env_vars={
                    "exe_start_date": '{{ macros.ds_add(ds, -364) }}',
                    "exe_end_date": '{{ ds }}',
                    "exe_type": 'fytd'
                }
            ),
            operator_args={
                    "install_deps": True,  # install any necessary dependencies before running any dbt command
                },
            render_config=render_config(config.DATA_TAG)
        )

        dbt_week >> dbt_fytd

    skiped_tasked = DummyOperator(task_id='skiped_tasked')
    false_task = DummyOperator(task_id='false_task', trigger_rule=TriggerRule.NONE_FAILED)

    wbr_breakout_report = DbtTaskGroup(
        group_id='refresh_wbr_breakout_report',
        profile_config=profile_config,
        project_config=ProjectConfig(
            dbt_project_path=project_path,
            env_vars={
                "exe_start_date": '{{ ds }}',
                "exe_end_date": '{{ ds }}',
                "exe_type": 'fytd'
            }
        ),
        operator_args={
                "install_deps": True,  # install any necessary dependencies before running any dbt command
            },
        render_config=render_config(config.BREAKOUT_REPORT)
    )

#    dbt_post = DummyOperator(task_id='dbt_post')

    dbt_post = DbtTaskGroup(
        group_id='refresh_l5_overview_table',
        profile_config=profile_config,
        project_config=ProjectConfig(
            dbt_project_path=project_path,
            env_vars={
                "exe_start_date": '{{ ds }}',
                "exe_end_date": '{{ ds }}',
                "exe_type": 'fytd'
            }
        ),
        operator_args={
                "install_deps": True,  # install any necessary dependencies before running any dbt command
            },
        render_config=render_config(config.OVR_VIEW)
    )
##    dbt_post.trigger_rule = TriggerRule.NONE_FAILED

    [sensor_customer, sensor_fm, sensor_marketing, sensor_marketing_evening, sensor_user_growth] >> dbt_day >> branch
    branch >> [week_fytd, skiped_tasked] >> false_task
    false_task >> wbr_breakout_report >> dbt_post

