"""
Daily scheduler — keeps a video uploading every day at DAILY_UPLOAD_TIME.
Run: python scheduler.py
Leave this process running (or add it to Windows Task Scheduler / a service).
"""
import logging
import sys

import schedule

import config

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
    stream=sys.stdout,
)
log = logging.getLogger("scheduler")


def _job():
    log.info("Scheduled job starting...")
    try:
        from main import run_pipeline
        video_id = run_pipeline()
        log.info(f"Job done → https://youtube.com/watch?v={video_id}")
    except Exception as exc:
        log.error(f"Job failed: {exc}", exc_info=True)


schedule.every().day.at(config.DAILY_UPLOAD_TIME).do(_job)

log.info(f"Scheduler active — next upload at {config.DAILY_UPLOAD_TIME} every day")
log.info("Press Ctrl+C to stop")

import time
while True:
    schedule.run_pending()
    time.sleep(60)
