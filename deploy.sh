#!/usr/bin/env bash
stack build
stack exec site clean
stack exec site build
