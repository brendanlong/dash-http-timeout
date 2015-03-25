#!/usr/bin/env python3
"""This script slowly copies DASH segments from the input folder to the output
   folder, to simulate a live DASH segmenter."""
import argparse
import itertools
import logging
import os
import re
import shutil
import sys
import time


def make_segment_re(template, number="*"):
    number = str(number)
    pattern = re.escape(
        args.segment_template.replace("$Number$", number)).replace("\*", ".*")
    return re.compile(pattern)


def list_files(directory):
    for _, _, files in os.walk(directory):
        for file in files:
            yield file


def copy_file(file, in_dir, out_dir):
    logging.debug("Copying %s from %s to %s." % (file, in_dir, out_dir))
    old_path = os.path.join(in_dir, file)
    new_path = os.path.join(out_dir, file)
    shutil.copyfile(old_path, new_path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--input", "-i",
        help="The directory to read segments from. Everything except .m4s "
             "files will be copied immediately.")
    parser.add_argument(
        "--output", "-o", help="The output directory", required=True)
    parser.add_argument(
        "--segment-duration", "-d", help="The duration of segments in seconds.",
        type=float, default=5.0)
    parser.add_argument(
        "--segment-template", "-t", help="Template for segment file names",
        default="segment-$Number$.*.m4s")
    parser.add_argument(
        "--start-number", "-n", help="First segment $Number$.",
        default=0, type=int)
    parser.add_argument(
        "--force", "-f", help="Clear output directory without confirmation.",
        action="store_true", default=False)
    parser.add_argument(
        "--verbose", "-v", action="store_true", default=False,
        help="Enable verbose output.")

    args = parser.parse_args()

    logging.basicConfig(
        format='%(levelname)s: %(message)s',
        level=logging.DEBUG if args.verbose else logging.INFO)

    if os.path.exists(args.output):
        if not args.force:
            choice = input("%s already exists. Delete it and recreate it? [y/N] " \
                % (args.output))
            if choice.lower() != "y":
                sys.exit(1)
        shutil.rmtree(args.output)
    os.makedirs(args.output, exist_ok=True)

    segment_re = make_segment_re(args.segment_template)
    for file in list_files(args.input):
        if not segment_re.match(file):
            logging.debug("Copying %s to output folder." % file)
            copy_file(file, args.input, args.output)

    for i in itertools.count(args.start_number):
        logging.info("Copying segment %s" % i)
        segment_re = make_segment_re(args.segment_template, i)
        logging.debug("Regular expression is %s" % segment_re)
        for file in list_files(args.input):
            if segment_re.match(file):
                copy_file(file, args.input, args.output)
        time.sleep(args.segment_duration)
