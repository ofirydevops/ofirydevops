import json
import os

import sys
import IPython
import jupyterlab
import notebook
import numpy as np
import pandas as pd
import polars as pl
import dask
import pyarrow as pa
import openpyxl
import xlrd
import sklearn
import xgboost as xgb
import lightgbm as lgb
import catboost
import torch
import torchvision
import torchaudio
import nltk
import spacy
import gensim
import transformers
import sentence_transformers
import matplotlib as mpl
import seaborn as sns
import plotly
import bokeh
import altair as alt
import skimage
import cv2
import tqdm
import rich
import ipywidgets as widgets
import black
import flake8
import mypy
import pre_commit
import requests
import httpx
import fastapi
import uvicorn
import flask
import sqlalchemy as sa
import psycopg2
import pymysql
import redis
import tinydb
import h5py
import zarr
import fsspec
import multipart
import yaml
import joblib
import hydra
import typer
import click
import PyQt5
import lxml
import bs4


def main():
    print("All packages imported successfully!")
    print(f"Python version: {sys.version}")


    print(f'CHILDJOB_BATCH_RUN_ID: {os.environ["CHILDJOB_BATCH_RUN_ID"]}')
    print(f'CHILDJOB_VOLUME_PATH: {os.environ["CHILDJOB_VOLUME_PATH"]}')
    print(f'CHILDJOB_INPUT_PATH: {os.environ["CHILDJOB_INPUT_PATH"]}')

    with open(os.environ["CHILDJOB_INPUT_PATH"], 'r') as f:
        child_job_input_dict = json.load(f)

    print(f"child_job_input_dict:\n{json.dumps(child_job_input_dict)}")

    print(f'some_key value: {child_job_input_dict["some_key"]}')



if __name__ == "__main__":
    main()

