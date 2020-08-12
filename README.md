# xnat-matlab-tool
A matlab tool to interface with XNAT.

You can use this tool to interface with XNAT with matlab programmatically.

Things you can do:
 -  Get information about projects, subjects, experiments, scans, resources or files
 -  Upload MR/PET/EEG data to XNAT
 -  Download MR/PET/EEG data to XNAT
 -  Update XNAT attributes like "series description", "date" or "type"
 -  Delete projects, subjects, experiments, scans, resources or files
 
 # Dependencies
 -  Matlab 2016 <

# Getting Started

## Login
The first step to use this tool is to login.

```Matlab
# method 1
xnat = XNATSession('xnat_username')   # a pop-up will prompt you for your password

# method 2
xnat = XNATSession('xnat_username', 'password', 'xnat_password')

# method 3
xnat = XNATSession('xnat_username', 'pass_file', '/path/to/pass_file.txt')    # path_file.txt must only contain your xnat password
```

*xnat_username* and *xnat_password* should be replaced with your xnat username and password respectively. 

Note: You must login before you can perform any of the following tasks. XNAT automatically logs you out after 15 mins of idle time. If this happens to you simply log in again before performing your actions. TODO: create a keep-alive background process

## Querying XNAT

```Matlab
# Get a cell array with information about all subjects in your XNAT project
project = 'TST01_CMH'
subjects = xnat.get_subjects(project)
subject{1}

subject = subject{1}.label

# Get a cell array with information about all experiments from a subject
experiments = xnat.get_experiments(project, subject)
experiments{1}

experiment = experiments{1}.label

# Get a cell array with information about all scans from an experiment
scans = get_scans(project, subject, experiment)
scans{1}

scan = scans{1}.ID
```

## Download Data
```Matlab

# download MR/PET or any dicom data from a given scan to a zipfile
data_file = xnat.download_dcm(project, subject, experiment, scan, 'data.zip')

# download EEG data from a given scan to a file
eeg_file = xnat.download_eeg(project, subject, experiment, scan, 'eeg_data.cnt')
```

## Upload Data
```Matlab

# Upload EEG data
experiment = 'TST01_CMH_00000001_03_SE01_EEG'
scan = '1'
task = 'rest'
local_file = 'eeg_data_to_upload.cnt'
filename = 'eeg_data_name_on_xnat.cnt'

resp = xnat.upload_eeg(project, subject, experiment, scan, task, local_file, filename)

attribute = 'date'
value = '02/30/20'
r = xnat.set_attribute( project, subject, experiment, attribute, value, scan)
```
