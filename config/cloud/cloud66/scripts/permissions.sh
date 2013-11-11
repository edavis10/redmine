#!/bin/bash
source /var/.cloud66_env
cd $RAILS_STACK_PATH
chown -R nginx:nginx files log tmp
chmod -R 755 files log tmp