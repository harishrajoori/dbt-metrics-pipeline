from airflow import DAG
from airflow.models.param import Param
from airflow.utils.task_group import TaskGroup
from airflow.utils.trigger_rule import TriggerRule
from airflow.operators.dummy import DummyOperator
from airflow.operators.python import BranchPythonOperator
from airflow.operators.python_operator import PythonOperator
from airflow.sensors.external_task import ExternalTaskSensor
from airflow.exceptions import AirflowFailException

from cosmos import ProjectConfig, DbtTaskGroup
from cosmos.config import RenderConfig, ProfileConfig
from cosmos.profiles import TrinoLDAPProfileMapping

import time
import datetime
from datetime import timedelta
import logging

from wbr.metrics_dbt.config import config as config

import wbr.metrics_dbt.plugins.utils as utils

log = logging.getLogger()

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
    dag_id="dag_metric_mart_backfill",
    max_active_runs=2,
    default_view='graph',
    schedule_interval="00 12 * * 0", # -- enable regular runs each sunday at 12pm utc -- #
    start_date=datetime.datetime.strptime('2023-01-01', "%Y-%m-%d"),
    catchup=False,
    concurrency=24,
    default_args={"retries": 0,
    'owner': 'Analytics Engineering',
    'on_failure_callback': utils.mece_dq_check_task_failure_callback},
    params={
            "backfill_start_date": Param(
                f"{datetime.date.today()-timedelta(days=7)}",
                type="string",
                format="date",
                title="Backfill Start Date",
                description_html="<p style='font-size:12px; font-family:tahoma; color:blue'>Business date to start backfilling from."
                "<br>Either specify in  <code style='color:red; background-color:lightgrey'>YYYY-MM-DD</code>  format, or use the Date Picker on the left."
                "<br>This input parameter is  <code style='color:red; background-color:lightgrey'>MANDATORY</code> !</p>"
                ),
            "backfill_end_date": Param(
                f"{datetime.date.today()-timedelta(days=1)}",
                type="string",
                format="date",
                title="Backfill End Date",
                description_html="<p style='font-size:12px; font-family:tahoma; color:blue'>Business date to to end backfilling on."
                "<br>Either specify in  <code style='color:red; background-color:lightgrey'>YYYY-MM-DD</code>  format, or use the Date Picker on the left."
                "<br>This input parameter is  <code style='color:red; background-color:lightgrey'>MANDATORY</code> !</p>"
                ),
            "backfill_models": Param(
                ','.join([x for x in config.BKFILL_MODELS]),
                type=["null", "string"],
                format="string",
                title="Backfill Model Names",
                description_html="<p style='font-size:12px; font-family:tahoma; color:blue'>Data Marts that are to be backfilled."
                "<br>Either specify as a comma-delimited string, or leave as-is / blank otherwise."
                "<br>This input parameter is  <code style='color:darkgreen; background-color:lightyellow'>OPTIONAL</code> ; defaults to all Data Marts if left blank.</p>"
                ),
            "json_config_toggle": Param(
                False,
                type="boolean",
                format="boolean",
                title="JSON Config Toggle",
                description_html="<p style='font-size:12px; font-family:tahoma; color:blue'>Enable/disable passing of above params as JSON Config."
                "<br>Toggle to ON to pass above params as JSON Config, or leave as OFF otherwise."
                "<br>This input parameter is  <code style='color:red; background-color:lightgrey'>MANDATORY</code> !</p>"
                )
        },
    render_template_as_native_obj=True
    ) as dag:


    def process_bkfill_params(bkfill_models, json_cfg_toggle, exec_dt, monday_bkfill_start_day_week, monday_bkfill_start_fytd, monday_bkfill_end, ondemand_bkfill_start_day_week, ondemand_bkfill_start_fytd, ondemand_bkfill_end, **context):
        time.sleep(2)
        run_id = context["dag_run"].run_id
        run_type = context["dag_run"].run_type
        skipped_models = list()
        ti = context['ti']
        all_task_instances = context['dag_run'].get_task_instances()
        if run_type == 'manual':
            # -- perform pre-executuion checks for an on-demand backfill run -- #
            if bkfill_models is None: # -- reset models list if cleared out -- #
                bkfill_models = config.BKFILL_MODELS
                log.info(f'-> Resetting Backfill Models To :: {bkfill_models}')
            if ondemand_bkfill_start_day_week > ondemand_bkfill_end: # -- raise error if backfill start date is after backfill end date -- #
                raise AirflowFailException("Backfill Start Date Must Predate Backfill End Date For An On-Demand Backfill Run!")
            if not json_cfg_toggle: # -- raise error if json config toggle has been left off -- #
                raise AirflowFailException("JSON Config Toggle Must Be Set To ON To Execute An On-Demand Backfill Run!")
            # -- perform operations (if pre-execution checks succeed) for an on-demand backfill run -- #
            all_models = config.BKFILL_MODELS
            # -- stop skipped_models from being set to None and cause for loop iteration to crash -- #
            if set(all_models) == set(bkfill_models):
                skipped_models = []
            else:
                skipped_models = list(set(all_models) - set(bkfill_models))
            if skipped_models:
                # -- mark "run" and "test" tasks as "success" for skipped models :: start --------------------------------- #
                for ti in all_task_instances:
                    # changes as per dat-1642 :: begin
                    for model in skipped_models:
                        if str(ti).split(' ')[1].split('.')[-2] == model and str(ti).split(' ')[1].split('.')[-1] == 'test':
                            ti.set_state('success')
                    time.sleep(1)
                    for model in skipped_models:
                        if str(ti).split(' ')[1].split('.')[-2] == model and str(ti).split(' ')[1].split('.')[-1] == 'run':
                            ti.set_state('success')
                    # changes as per dat-1642 :: end
                # -- mark "run" and "test" tasks as "success" for skipped models :: end ----------------------------------- #
        # -- logging of task params for weekly monday and on-demand backfill runs -- #
        if json_cfg_toggle and run_type == 'manual': # -- on-demand backfill run -- #
            bkfill_run_type = "On-Demand Backfill Run"
            bkfill_start_dt_day_week = ondemand_bkfill_start_day_week
            bkfill_start_dt_fytd = ondemand_bkfill_start_fytd
            bkfill_end_dt = ondemand_bkfill_end
        else: # -- weekly monday run -- #
            bkfill_run_type = "Weekly Monday Run"
            # bkfill_start_dt_day_week = (datetime.datetime.strptime(exec_dt, "%Y-%m-%d") - datetime.timedelta(days=1)).date()
            # bkfill_start_dt_fytd = (datetime.datetime.strptime(exec_dt, "%Y-%m-%d") - datetime.timedelta(days=367)).date()
            # bkfill_end_dt = (datetime.datetime.strptime(exec_dt, "%Y-%m-%d") + datetime.timedelta(days=5)).date()
            bkfill_start_dt_day_week = monday_bkfill_start_day_week
            bkfill_start_dt_fytd = monday_bkfill_start_fytd
            bkfill_end_dt = monday_bkfill_end
        log.info('\n' + '-'*100 + '\n' + \
                f'-> Executing A {bkfill_run_type} | JSON Config Toggle Was {json_cfg_toggle} | Details And Date Ranges Are As Follows ::\
                \n\t - Run ID -: {run_id}\
                \n\t - Run Type -: {run_type}\
                \n\t - Execution Date = {exec_dt}\
                \n\t - DAY  Aggregation -: From {bkfill_start_dt_day_week} To {bkfill_end_dt}\
                \n\t - WEEK Aggregation -: From {bkfill_start_dt_day_week} To {bkfill_end_dt}\
                \n\t - FYtD Aggregation -: From {bkfill_start_dt_fytd} To {bkfill_end_dt}\
                \n\t - Models To Be Backfilled Are -: {bkfill_models}\
                \n\t - Models To Be Skipped Are -: {skipped_models}'\
                + '\n' + '-'*100 + '\n')
        time.sleep(2)


    process_bkfill_params = PythonOperator(
        task_id="process_bkfill_params",
        python_callable=process_bkfill_params,
        op_args=[
            "{{ params.backfill_models}}",
            "{{ params.json_config_toggle }}",
            "{{ ds }}",
            "{{ macros.ds_add(ds, -1) }}",
            "{{ macros.ds_add(ds, -367) }}",
            "{{ macros.ds_add(ds, -5) }}",
            "{{ params.backfill_start_date }}",
            "{{ params.backfill_start_date }}",
            "{{ params.backfill_end_date }}"
        ],
        dag=dag,
        provide_context=True
    )


    if "{{ params.json_config_toggle }}": # JSON Config Toggle is ON, indicating a On-Demand Backfill Run

    # -- BELOW CODE SNIPPET CORRESPONDS TO THE TASKGROUP DEFINITIONS WHEN A ON-DEMAND BACKFILL RUN EXECUTES OVER A PERIOD DEFINED BY BACKFILL START DATE AND BACKFILL END DATE ---------------------- #
        with TaskGroup(
            group_id="wrapper_taskgroup",
            tooltip="Update L4 Data Marts and L5 Aggregate Tables For On-Demand Backfill Run",
        ) as wrapper_taskgroup:

            day_aggregation = DbtTaskGroup(
                group_id='day_aggregation',
                profile_config=profile_config,
                project_config=ProjectConfig(
                    dbt_project_path=config.PROJECT_PATH,
                    env_vars={
                        "exe_start_date": "{{ params.backfill_start_date }}",
                        "exe_end_date": "{{ params.backfill_end_date }}",
                        "exe_type": 'day'
                    }
                ),
                operator_args={
                        "install_deps": True,  # install any necessary dependencies before running any dbt command
                    },
                render_config=render_config(config.DATA_TAG)
            )

            with TaskGroup(group_id='week_fytd_aggregations') as week_fytd_aggregations:
                week_aggregation = DbtTaskGroup(
                    group_id='week_aggregation',
                    profile_config=profile_config,
                    project_config=ProjectConfig(
                        dbt_project_path=config.PROJECT_PATH,
                        env_vars={
                            "exe_start_date": "{{ params.backfill_start_date }}",
                            "exe_end_date": "{{ params.backfill_end_date }}",
                            "exe_type": 'week'
                        }
                    ),
                    operator_args={
                            "install_deps": True,  # install any necessary dependencies before running any dbt command
                        },
                    render_config=render_config(config.DATA_TAG)
                )

                fytd_aggregation = DbtTaskGroup(
                    group_id='fytd_aggregation',
                    profile_config=profile_config,
                    project_config=ProjectConfig(
                        dbt_project_path=config.PROJECT_PATH,
                        env_vars={
                            "exe_start_date": "{{ params.backfill_start_date }}",
                            "exe_end_date": "{{ params.backfill_end_date }}",
                            "exe_type": 'fytd'
                        }
                    ),
                    operator_args={
                            "install_deps": True,  # install any necessary dependencies before running any dbt command
                        },
                    render_config=render_config(config.DATA_TAG)
                )

                week_aggregation >> fytd_aggregation

            with TaskGroup(group_id='l5_aggregations') as l5_aggregations:
                refresh_wbr_breakout_report = DbtTaskGroup(
                    group_id='refresh_wbr_breakout_report',
                    profile_config=profile_config,
                    project_config=ProjectConfig(
                        dbt_project_path=config.PROJECT_PATH,
                        env_vars={
                            "exe_start_date": "{{ params.backfill_start_date }}",
                            "exe_end_date": "{{ params.backfill_end_date }}",
                            "exe_type": 'fytd'
                        }
                    ),
                    operator_args={
                            "install_deps": True,  # install any necessary dependencies before running any dbt command
                        },
                    render_config=render_config(config.BREAKOUT_REPORT)
                )

                refresh_wbr_overview_table = DbtTaskGroup(
                    group_id='refresh_wbr_overview_table',
                    profile_config=profile_config,
                    project_config=ProjectConfig(
                        dbt_project_path=config.PROJECT_PATH,
                        env_vars={
                            "exe_start_date": "{{ params.backfill_start_date }}",
                            "exe_end_date": "{{ params.backfill_end_date }}",
                            "exe_type": 'fytd'
                        }
                    ),
                    operator_args={
                            "install_deps": True,  # install any necessary dependencies before running any dbt command
                        },
                    render_config=render_config(config.OVR_VIEW)
                )

                refresh_wbr_breakout_report >> refresh_wbr_overview_table

            day_aggregation >> week_fytd_aggregations >> l5_aggregations
    # -- ABOVE CODE SNIPPET CORRESPONDS TO THE TASKGROUP DEFINITIONS WHEN A ON-DEMAND BACKFILL RUN EXECUTES OVER A PERIOD DEFINED BY BACKFILL START DATE AND BACKFILL END DATE ---------------------- #

    process_bkfill_params >> wrapper_taskgroup
