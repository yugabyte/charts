#!/usr/bin/env python
"""Openshift helm charts certification"""

import os
from shutil import which, copytree
import subprocess
import logging
import sys
import argparse
import json
import hiyapyco
import yaml

logging.basicConfig(
    level=logging.INFO,
    stream=sys.stdout,
    format="%(asctime)s %(levelname)s %(message)s",
)


def generate_schema_json(values_file, path_for_schema, additional_properties=False):
    """Generate schema.json from values.yaml. Use quicktype to generate the schema"""
    # verify yq and quicktype exists
    for command_should_present in ["quicktype"]:
        if not which(command_should_present):
            raise Exception(f"{command_should_present} command does not exists")

    if not os.path.exists(values_file):
        raise FileNotFoundError(f"{values_file} not found")

    abs_path_values = os.path.abspath(values_file)
    abs_path_schema = os.path.join(
        os.path.abspath(path_for_schema), "values.schema.json"
    )

    with open(abs_path_values, "r", encoding="UTF-8") as yaml_file:
        values_yaml = yaml.safe_load(yaml_file)

    yaml_to_json = json.dumps(values_yaml)

    quicktype_cmd = f"quicktype --lang schema --out {abs_path_schema}".split(" ")

    schema_generation = subprocess.Popen(
        quicktype_cmd,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
    )
    schema_generation.stdin.write(yaml_to_json)
    _, errors = schema_generation.communicate()

    if errors:
        raise Exception(errors)

    if additional_properties:
        # update additionalProperties to true
        with open(abs_path_schema, "r", encoding="UTF-8") as schema_read:
            schema_data = json.loads(schema_read.read())

        for key in schema_data["definitions"].keys():
            if isinstance(schema_data["definitions"][key], dict):
                schema_data["definitions"][key]["additionalProperties"] = True

        with open(abs_path_schema, "w", encoding="UTF-8") as schema_write:
            json.dump(schema_data, schema_write, indent=4)


def update_chart_name(chart_path):
    """Add -openshift in front of chart name in Chart.yaml"""

    path_to_chart_yaml = os.path.join(chart_path, "Chart.yaml")

    if not os.path.exists(path_to_chart_yaml):
        raise FileNotFoundError(f"{path_to_chart_yaml} not found")

    with open(path_to_chart_yaml, "r", encoding="UTF-8") as chart:
        chart_data = yaml.load(chart, Loader=yaml.SafeLoader)

    if not "-openshift" in chart_data["name"]:
        chart_data["name"] = chart_data["name"] + "-openshift"
        chart_data["annotations"]["charts.openshift.io/name"] = chart_data["name"]

        with open(path_to_chart_yaml, "w", encoding="UTF-8") as chart:
            yaml.dump(chart_data, chart, sort_keys=False)


def apply_overrides(original_values, ocp_overrides):
    """Generate OCP compatible values.yaml"""

    if not os.path.exists(original_values):
        raise FileNotFoundError(f"{original_values} not found")

    if not os.path.exists(ocp_overrides):
        raise FileNotFoundError(f"{ocp_overrides} not found")

    merged_values = hiyapyco.load(
        original_values,
        ocp_overrides,
        method=hiyapyco.METHOD_MERGE,
        interpolate=True,
        failonmissingfiles=True,
    )

    with open(original_values, "w", encoding="UTF-8") as values_file:
        values_file.write(hiyapyco.dump(merged_values))


if __name__ == "__main__":

    parser = argparse.ArgumentParser()
    parser.add_argument("--chart", help="Charts Path", required=True)
    parser.add_argument(
        "--enable_additional_properties",
        action="store_true",
        help="Make additionalProperties: true",
        default=True,
    )
    args_group = parser.add_mutually_exclusive_group(required=True)
    args_group.add_argument(
        "--generate_schema_json",
        help="Generate values.schema.json against values.yaml",
        action="store_true",
    )
    args_group.add_argument(
        "--generate_ocp_charts",
        help="Generate OCP certificaiton compatible charts",
        action="store_true",
    )

    args = parser.parse_args()

    # get charts absolute path
    abs_charts_path = os.path.abspath(args.chart)

    if args.generate_schema_json:
        # Generate values.schema.json
        logging.info(
            "Generating values.schema.json for values.yaml - %s", abs_charts_path
        )
        generate_schema_json(
            os.path.join(abs_charts_path, "values.yaml"),
            abs_charts_path,
            args.enable_additional_properties,
        )

    if args.generate_ocp_charts:
        # Generate workdir for OCP compatible charts
        ocp_chart_path = abs_charts_path + "-openshift"
        logging.info("Checking OCP working directories exists - %s", ocp_chart_path)
        if not os.path.exists(ocp_chart_path):
            os.makedirs(ocp_chart_path)
            logging.info("Created OCP working directories - %s", ocp_chart_path)

        # copy data to charts repo to ocp charts work directory
        logging.info(
            "Copying data from charts directory - %s - to - %s",
            abs_charts_path,
            ocp_chart_path,
        )
        copytree(
            os.path.abspath(abs_charts_path),
            os.path.abspath(ocp_chart_path),
            dirs_exist_ok=True,
        )

        # Generate OCP compatible values.yaml
        logging.info("Generating OCP compatible values.yaml - %s", ocp_chart_path)
        apply_overrides(
            os.path.join(ocp_chart_path, "values.yaml"),
            os.path.join(ocp_chart_path, "openshift.values.yaml"),
        )

        # Generate values.schema.json
        logging.info(
            "Generating values.schema.json for OCP compatible values.yaml - %s",
            ocp_chart_path,
        )
        generate_schema_json(
            os.path.join(ocp_chart_path, "values.yaml"),
            ocp_chart_path,
            args.enable_additional_properties,
        )

        # Update chart name
        logging.info(
            "Updating chart name in Chart.yaml - %s",
            ocp_chart_path,
        )
        update_chart_name(ocp_chart_path)
