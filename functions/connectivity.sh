#!/bin/bash

function check_github() {
	ssh -T git@github.com 2>&1
}
