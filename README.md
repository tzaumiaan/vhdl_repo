# VHDL Repo

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

## Operation types
All operations are run at the module directory.
```
cd [module_name]
```

Python script is used as the backbone of all operations,
so remember to activate a `conda` environment with required packages,
e.g. `ruamel.yaml`, `pylint`, `numpy`, etc.
```
conda create -n [conda_env_name] python numpy pylint ruamel.yaml
conda activate [conda_env_name]
```

1. Linting check (compilation without testbench)
```
./run.sh lint
```

2. Compile and simulation
```
./run.sh sim
```

3. Debugging with waveform
```
./run.sh view -s [fixed_case_name]
```

## Scripts
All scripts are kept in `scripts` folder.
Before making commits, run the following to ensure a clean coding style.
```
cd [repository_root]
pylint scripts
```

