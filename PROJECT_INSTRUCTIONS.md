# Project Setup

1. Update submodules
    ```sh
    git submodule update --init --recursive
    ```
2. Create  and enter virtual environment (root of project)
    ```sh
    python3 -m venv fprime-venv
    . fprime-venv/bin/activate
    ```
3. Install requirements.txt in fprime
    ```sh
    cd lib/fprime
    pip install -r requirements.txt
    ```
4. Install requirements.txt in fprime-arduino
    ```sh
    cd ../fprime-featherm4-freertos/fprime-arduino
    pip install -r requirements.txt
    ```
5. Install all these arduino-cli related code
    ```sh
    cd ../../..

    curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | BINDIR=$VIRTUAL_ENV/bin sh

    pip install git+https://github.com/CubeSTEP/arduino-cli-cmake-wrapper.git@main

    arduino-cli config init

    arduino-cli config add board_manager.additional_urls https://github.com/stm32duino/BoardManagerFiles/raw/main/package_stmicroelectronics_index.json

    arduino-cli core update-index
    
    arduino-cli core install STMicroelectronics:stm32
    ```
6. Run fprime-util generate
    ```sh
    fprime-util generate
    ```

7. Run the build command 
    ```sh
    fprime-util build
    ```

# Flashing the Board

## Flashing command
```sh
# In ubuntu 22.04
sudo sh ~/.arduino15/packages/STMicroelectronics/tools/STM32Tools/2.4.0/stm32CubeProg.sh -i swd -f build-artifacts/FeatherM4_FreeRTOS/ReferenceDeployment/bin/ReferenceDeployment.elf.hex -c /dev/ttyAMC0

# If the above command does not work for your OS, follow this format (This might work depending on your OS)
sudo sh {path to stm32CubeProg.sh} -i swd -f build-artifacts/FeatherM4_FreeRTOS/ReferenceDeployment/bin/ReferenceDeployment.elf.hex -c {path to board connection}
```

## Possible Issue for Ubuntu
This error might print out when running the flash command.
```sh
STM32CubeProgrammer not found (STM32_Programmer.sh)
    Please install it or add '<STM32CubeProgrammer path>/bin' to your PATH environment
```
To fix this, go to ~/.arduino15/packages/STMicroelectronics/tools/STM32Tools/2.4.0/stm32CubeProg.sh and edit the file. Remove this line in line 70.
```sh
export PATH="$HOME/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin":"$PATH
```
Replace it with the line below. Switch out {name} for the appropriate name. The error was that $HOME in the bash file did not provide the right path.
```sh
export PATH="home/{name}/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin":"$PATH
```

# Run fprime-gds

## fprime-gds command
```sh
# In ubuntu 22.04
fprime-gds -n --dictionary build-artifacts/FeatherM4_FreeRTOS/ReferenceDeployment/dict/ReferenceDeploymentTopologyDictionary.json --communication-selection uart --uart-device /dev/ttyACM0 --uart-baud 115200 --framing-selection fprime

# If the above command does not work for your OS, follow this format
fprime-gds -n --dictionary build-artifacts/FeatherM4_FreeRTOS/ReferenceDeployment/dict/ReferenceDeploymentTopologyDictionary.json --communication-selection uart --uart-device {path to board connection} --uart-baud 115200 --framing-selection fprime
```

## Possible Issue
If the top right shows a red x, then a connection has not been made. It is possible that folder representing the board connnection is not providing the permissions needed to run fprime-gds.

For Ubuntu, run this command.
```sh
sudo chmod 666 /dev/ttyACM0
```
Afterwards, run the fprime-gds command again. For other OSes, you must run a command that elevates the permission for the folder representing the board connection.