#!/usr/bin/env python3
"""Python script to find Docker image tag from YugabyteDB release version"""
from optparse import OptionParser
from re import match
from requests import request
from sys import exit

DOCKER_TAGS_URL = "https://registry.hub.docker.com/v2/repositories/yugabytedb/yugabyte/tags"


def main(release):
    """Use YugabyteDB release version to find respective docker image tag"""
    if not match("[0-9]+.[0-9]+.[0-9]+.[0-9]+", release.version):
        exit("Version validation failed: required format: *.*.*.*")

    response = request(method='GET', url=DOCKER_TAGS_URL)
    if not response.ok:
        exit("Got {} from {}.".format(response.status_code, DOCKER_TAGS_URL))
    json_response = response.json()

    tags = dict()
    for tag_obj in json_response['results']:
        tag = tag_obj['name']
        # Skip tags with architecture i.e. 2.18.5.1-b1-x86_64
        if tag.startswith(release.version) and tag.count("-") == 1:
            build_number = int(tag[tag.rindex("-b")+2:])
            tags[build_number] = tag
    if not tags:
        exit("Given version did not match any of the tags")

    latest_build = max(tags.keys())
    print(tags[latest_build])


if __name__ == "__main__":
    usage = "usage: %prog [options] -r <release-version>"
    parser = OptionParser(usage)
    parser.add_option("-r", "--release", type="string", dest="version")

    (ARGS, OPTIONS) = parser.parse_args()

    for option in ARGS.__dict__:
        if ARGS.__dict__[option] is None:
            parser.error("failed to parse the arguments.")
    main(ARGS)
