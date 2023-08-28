#!/bin/bash

# Run exporter in a tmux session
tmux new-session -s pilot-test -d "CUDA_VISIBLE_DEVICES=0 PROJECT=exporter pinto -p exporter run -e /home/kamalan/DeepClean/projects/.env flask --app=exporter run"

# all the other projects require communicating with the
# export service, so wait until it's online before
# launching the remainder of the services
while [[ -z $(curl -s localhost:5000/alive) ]]; do
    echo "Waiting for export service to come online"
    sleep 2
done

# Run trainer
tmux split-window -v "CUDA_VISIBLE_DEVICES=0 PROJECT=trainer pinto -p trainer run -e /home/kamalan/DeepClean/projects/.env train --typeo pyproject.toml script=train architecture=autoencoder"

# Launching triton server
tmux split-window -h "
    CUDA_VISIBLE_DEVICES=1 singularity exec \
        --nv /home/kamalan/triton/tritonserver.sif \
        /opt/tritonserver/bin/tritonserver \
            --model-repository ${HOME}/deepclean/model_repo \
            --model-control-mode poll \
            --repository-poll-secs 10 \
"

# Run cleaner
tmux split-window -v "PROJECT=cleaner pinto -p cleaner run -e /home/kamalan/DeepClean/projects/.env clean --typeo pyproject.toml script=clean"

# Run monitor
tmux split-window -v "PROJECT=monitor pinto -p monitor run -e /home/kamalan/DeepClean/projects/.env monitor --typeo pyproject.toml script=monitor"
