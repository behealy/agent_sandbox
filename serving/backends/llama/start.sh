
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

darwin_load() {
    # Get Model Name
    MODEL=$(system_profiler SPHardwareDataType | grep "Model Name:" | awk -F': ' '{print $2}')

    # Get Chip
    CHIP=$(system_profiler SPHardwareDataType | grep "Chip:" | awk -F': ' '{print $2}')

    # Get Memory
    MEM=$(system_profiler SPHardwareDataType | grep "Memory:" | awk -F': ' '{print $2}')

    # Get Model Identifier (contains size info implicitly like '16,1')
    ID=$(system_profiler SPHardwareDataType | grep "Model Identifier:" | awk -F': ' '{print $2}')

    echo "Model: $MODEL ($ID)"
    echo "Chip: $CHIP"
    echo "Memory: $MEM"

    if [[ "$CHIP" == "Apple M4 Pro" ]]; then
        cfg="$SCRIPT_DIR/model_configs/m4Pro_24g.ini"
    elif [[ "$CHIP" == "Apple M1 Pro" ]]; then
        cfg="$SCRIPT_DIR/model_configs/m1Pro_32g.ini"
    elif [[ "$CHIP" == "Apple M2 Max" ]]; then
        cfg="$SCRIPT_DIR/model_configs/m2Max_32g.ini"
    fi
    echo "Using llama-server presets:"
    echo $cfg
    llama-server --host 127.0.0.1  --port 4321 --models-preset "$cfg"
}

if [ "$(uname -s)" = "Darwin" ]; then
    darwin_load
elif [ "$(uname -s)" = "Linux" ]; then
    echo "You are running on Linux"
else
    echo "Unknown OS"
fi
