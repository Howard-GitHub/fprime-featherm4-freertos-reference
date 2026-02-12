# Project Setup

1. Create virtual environment (root of project)
    ```sh
    python3 -m venv fprime-venv
    ```
2. Install requirements.txt in fprime
    ```sh
    cd lib/fprime
    pip install -r requirements.txt
    ```
3. Install requirements.txt in fprime-arduino
    ```sh
    cd ../fprime-featherm4-freertos/fprime-arduino
    pip install -r requirements.txt
    ```
4. Install all these arduino-cli related code
    ```sh
    cd ../../..
    curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | BINDIR=$VIRTUAL_ENV/bin sh
    pip install arduino-cli-cmake-wrapper
    arduino-cli config init
    arduino-cli config add board_manager.additional_urls https://github.com/stm32duino/BoardManagerFiles/raw/main/package_stmicroelectronics_index.json
    arduino-cli core update-index
    arduino-cli core install STMicroelectronics:stm32
    ```
5. Run fprime-util generate
    ```sh
    fprime-util generate
    ```