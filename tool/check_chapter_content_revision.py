"""Check a content revision, using five chapters unless an end is supplied."""

import argparse

from check_chapters_06_10_revision import verify

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--start-chapter", type=int, required=True)
    parser.add_argument("--end-chapter", type=int)
    arguments = parser.parse_args()
    verify(arguments.start_chapter, arguments.end_chapter)
