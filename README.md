# VHDL Blocks

Repository for VHDL blocks and RTL simulation environment

## File structures
```
vhdl_blocks
├── scripts
|   ├── main.py
│   └── *.py
└── [module_name]
    ├── config.yml
    ├── run.bat
    ├── rtl
    |   ├── [module_name]_top.vhd
    |   └── *.vhd
    ├── tb
    |   ├── tb.vhd
    |   └── *.vhd
    ├── sim
    |   ├── sim.tcl
    |   ├── *.wcfg (optional)
    |   └── [fixed_case_name]
    |       ├── sim.tcl (optional)
    |       └── *.txt
    └── work_* (generated in runtime, never committed)
        ├── xsim.dir
        ├── *.log
        └── [fixed_case_name]
            ├── xsim.dir (symlink)
            ├── sim.tcl (symlink)
            ├── *.wcfg (optional, symlink)
            ├── *.log
            └── *.txt
```

## Python environment
Python script is used as the backbone of all operations,
so remember to activate a `conda` environment with required packages,
e.g. `ruamel.yaml`, `pylint`, `black`, `numpy`, etc.
```
conda create -n [conda_env_name] python numpy black pylint ruamel.yaml
conda activate [conda_env_name]
```

Note:
All scripts are kept in `scripts` folder.
Before making commits on scripts, run the following to ensure a clean coding style.
```
cd [repository_root]
black scripts -l 100
pylint scripts
```

## Module creation
1. Create a folder with the name of the module, and enter it.
```
cd [repository_root]
mkdir [module_name]
cd [module_name]
```
2. Prepare a `run.bat` under module root with the following contents. (Windows)
```
@echo off
call python ..\scripts\main.py %* -m win_local
```
Or a `run.sh` under module root with the following contents. (Linux)
```
python ../scripts/main.py "$@" -m linux_local
```
Use `run` (Windows) or `./run.sh` (Linux) to run the script.
```
run init
```

## Operation types
All operations are run at the module directory.
```
cd [module_name]
```

1. Linting check (compilation without testbench)
```
run lint
```

2. Compile and simulation
```
run sim
```

3. Debugging with waveform
```
run view -s [fixed_case_name]
```

