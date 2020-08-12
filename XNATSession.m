classdef XNATSession
    % XNAT Interface Class for communicating with XNAT
    %   Detailed explanation goes here
    
    
    properties
        username
        password
        host
        verify
        jsessionid
        debug
    end
    
    methods        
        function obj = XNATSession(username, varargin)
            %TESTCLASS Construct an instance of this class
            %   Detailed explanation goes here
            % Setup, check and read input parameters 
            p = inputParser;

            defaultPass = '';
            defaultHost = 'https://xnat.camh.ca/xnat'; 
            defaultVerify = true;
            defaultJsessionid = '';
            defaultDebug = false;

            addRequired(p, 'username', @ischar);
            addParameter(p, 'password', defaultPass, @ischar);
            addParameter(p, 'pass_file', defaultPass, @ischar);
            addParameter(p, 'host', defaultHost, @ischar);
            addParameter(p, 'verify', defaultVerify, @islogical);
            addParameter(p, 'jsessionid', defaultJsessionid, @ischar);
            addParameter(p, 'debug', defaultDebug, @islogical);

            parse(p, username, varargin{:});

            obj.username = p.Results.username;
            obj.host = p.Results.host;
            obj.verify = p.Results.verify;
            obj.jsessionid = p.Results.jsessionid;
            obj.debug = p.Results.debug;
            obj.password = XNATSession.get_password(username, ...
                                            p.Results.password, ...
                                            p.Results.pass_file);
            
            if isempty(obj.jsessionid)
                obj = obj.login();
            end
        end
        
        function obj = login(obj)
            % Login to XNAT and set JSESSIONID for session
            options = weboptions('Username', obj.username,...
                                    'Password', obj.password,...
                                    'RequestMethod', 'POST',...
                                    'KeyName', 'verify',...
                                    'KeyValue', obj.verify);
            obj.jsessionid = webread(strcat(obj.host, '/data/JSESSION'),...
                                     options);
            if obj.debug
                disp(['JSESSIONID: ' obj.jsessionid])
            end
        end
        
        function resp = post(obj, path, query )
            % Return http response from POST request
            %
            % Args:
            %       obj :: XNATSession object
            %           XNATSession object instance with jsessionid and
            %           host set.
            %
            %       path :: string
            %           URI endpoint path (ex. /data/projects)
            %
            %       query :: {key, valye}
            %           Cell array of key value pairs for http query
            %           parameters.
            %
            % Return:
            %       resp :: struct
            %           Http response structure.
            %           Ex. collections = resp.ResultSet.Result(n)
            %               entities    =
            %               resp.items.<children/data_fields/meta>
            %
            resp = request_(obj, 'POST', path, query );
        end
        
        function resp = get(obj, path, query )
            % Return http response from GET request
            %
            % Args:
            %       obj :: XNATSession object
            %           XNATSession object instance with jsessionid and
            %           host set.
            %
            %       path :: string
            %           URI endpoint path (ex. /data/projects)
            %
            %       query :: {key, valye}
            %           Cell array of key value pairs for http query
            %           parameters.
            %
            % Return:
            %       resp :: struct
            %           Http response structure.
            %           Ex. collections = resp.ResultSet.Result(n)
            %               entities    =
            %               resp.items.<children/data_fields/meta>
            %
            resp = request_(obj, 'GET', path, query );
        end
        
        function resp = put(obj, path, query )
            % Return http response from PUT request
            %
            % Args:
            %       obj :: XNATSession object
            %           XNATSession object instance with jsessionid and
            %           host set.
            %
            %       path :: string
            %           URI endpoint path (ex. /data/projects)
            %
            %       query :: {key, valye}
            %           Cell array of key value pairs for http query
            %           parameters.
            %
            % Return:
            %       resp :: struct
            %           Http response structure.
            %           Ex. collections = resp.ResultSet.Result(n)
            %               entities    =
            %               resp.items.<children/data_fields/meta>
            %
            resp = request_(obj, 'PUT', path, query );
        end
        
        function resp = delete(obj, path, query )
            % Return http response from DELETE request
            %
            % Args:
            %       obj :: XNATSession object
            %           XNATSession object instance with jsessionid and
            %           host set.
            %
            %       path :: string
            %           URI endpoint path (ex. /data/projects)
            %
            %       query :: {key, valye}
            %           Cell array of key value pairs for http query
            %           parameters.
            %
            % Return:
            %       resp :: struct
            %           Http response structure.
            %           Ex. collections = resp.ResultSet.Result(n)
            %               entities    =
            %               resp.items.<children/data_fields/meta>
            %
            resp = request_(obj, 'DELETE', path, query );
        end
        
        function resp = request_(obj, method, path, query, varargin )
            % Return response of http request
            %
            % Args:
            %       query {cell array}
            %           Must be a cell array of name-value pairs.
            %
            if isequal(nargin, 3)
                query = {};
                data = '';
                headers = {};
            elseif isequal(nargin, 4)
                data = '';
                headers = {};
            elseif isequal(nargin, 5)
                data = varargin{1};
                headers = {};
            elseif isequal(nargin, 6)
                data = varargin{1};
                headers = varargin{2};
            end
            
            options = weboptions('RequestMethod', method, ...
                              'KeyName', 'cookie', ...
                              'KeyValue', ['JSESSIONID=', obj.jsessionid],...
                              'Timeout', 60, ...
                              'HeaderFields', string(headers));
            if obj.debug
                path
                options
            end
            
            if isempty(data)
                resp = webread(strcat(obj.host, path), query{:}, options);
            else
                % webwrite doesn't accept query parameters with data so
                % need to add them together first
                path = XNATSession.construct_url(path, query);
                resp = webwrite(strcat(obj.host, path), data, ...
                                 options);
            end
            

        end
        
        function scans = get_scans(obj, project, experiment)
            % Return a cell array of structs scan data
            %
            % Args:
            %       obj :: XNATSession object
            %           XNATSession object instance with jsessionid and
            %           host set.
            %
            %       project :: string
            %           XNAT project name (ex. ABC01_CMH)
            %
            %       experiment :: string
            %           XNAT Experiment name.
            %           (ex. ABC01_CMH_00001_01_SE01_MR)
            %
            % Return:
            %       scans :: {structs}
            %           A cell array with each element a scan structure.
            %
            path = ['/data/projects/' project '/experiments/' experiment ...
                    '/scans' ];
            query = {'format', 'json'};
            
            % Check if it exists
            resp = request_(obj, 'GET', path, query );
            
            if obj.debug
                resp
            end
            % Get the scan index and return a cell array of scan data
            idx = XNATSession.find_index({resp.items.children.field}, 'scan');
            scans = {resp.items.children(idx).items(:).data_fields};
        end
        
        function scan_cell = get_scan(obj, project, subject, experiment, scan)
            % Return a scan struct
            %
            % Args:
            %       obj :: XNATSession object
            %           XNATSession object instance with jsessionid and
            %           host set.
            %
            %       project :: string
            %           XNAT project name (ex. ABC01_CMH)
            %
            %       experiment :: string
            %           XNAT Experiment name.
            %           (ex. ABC01_CMH_00001_01_SE01_MR)
            %
            %       scan :: string
            %           XNAT scan ID.
            %           (ex. '0')
            %
            % Return:
            %       scan_cell :: struct
            %           a single scan struct.
            %
            path = ['/data/projects/' project '/subjects/' subject ...
                    '/experiments/' experiment '/scans/' scan ];
            query = {'format', 'json'};
            
            % Check if it exists
            resp = request_(obj, 'GET', path, query );
            
            if obj.debug
                resp
            end
            
            scan_cell = append_struct(resp.items.data_fields,...
                                       resp.items.meta);
        end
        
        function resources = get_resources(obj, project, subject, ...
                                            experiment, scan) 
            % Return a cell array of structs scan data
            %
            % Args:
            %       obj :: XNATSession object
            %           XNATSession object instance with jsessionid and
            %           host set.
            %
            %       project :: string
            %           XNAT project name (ex. ABC01_CMH)
            %
            %       experiment :: string
            %           XNAT Experiment name.
            %           (ex. ABC01_CMH_00001_01_SE01_MR)
            %
            %       scan :: string
            %           XNAT scan ID.
            %           (ex. '0')
            %
            % Return:
            %       scans :: {structs}
            %           A cell array with each element a scan structure.
            %
            path = ['/data/projects/' project '/subjects/' subject ...
                    '/experiments/' experiment '/scans/' scan ...
                    '/resources'];
            query = {'format', 'json'};
            
            % Check if it exists
            resp = request_(obj, 'GET', path, query );
            
            if obj.debug
                resp
            end
            % Get the scan index and return a cell array of scan data
            resources = num2cell(resp.ResultSet.Result);
        end
        
        function files = get_files(obj, project, subject, experiment,...
                                             scan )
            % Return a cell array of structs files
            %
            % Args:
            %       obj :: XNATSession object
            %           XNATSession object instance with jsessionid and
            %           host set.
            %
            %       project :: string
            %           XNAT project name (ex. ABC01_CMH)
            %
            %       experiment :: string
            %           XNAT Experiment name.
            %           (ex. ABC01_CMH_00001_01_SE01_MR)
            %
            %       scan :: string
            %           XNAT scan ID.
            %           (ex. '0')
            %
            % Return:
            %       scans :: {structs}
            %           A cell array with each element a scan structure.
            %
            path = ['/data/projects/' project '/subjects/' subject ...
                    '/experiments/' experiment '/scans/' scan ...
                    '/files'];
            query = {'format', 'json'};
            
            % Check if it exists
            resp = request_(obj, 'GET', path, query );
            
            if obj.debug
                resp
            end
            % Get the scan index and return a cell array of scan data
            files = num2cell(resp.ResultSet.Result);
        end
        
        function experiments = get_experiments(obj, project, subject)
            % Return a cell array of structs experiment data
            %
            % Args:
            %       obj :: XNATSession object
            %           XNATSession object instance with jsessionid and
            %           host set.
            %
            %       project :: string
            %           XNAT project name. (ex. ABC01_CMH)
            %
            %       subject :: string
            %           XNAT Experiment name.
            %           (ex. ABC01_CMH_00001)
            %
            % Return:
            %       scans :: {structs}
            %           A cell array with each element a scan structure.
            %
            path = ['/data/projects/' project '/subjects/' subject ...
                    '/experiments' ];
            query = {'format', 'json'};
            
            % Check if it exists
            resp = request_(obj, 'GET', path, query );
            
            if obj.debug
                resp
            end
            % Get the scan index and return a cell array of scan data
            experiments = num2cell(resp.ResultSet.Result);
        end
        
        function expr_cell = get_experiment(obj, project, subject, experiment)
            % Return a experiment struct
            %
            % Args:
            %       obj :: XNATSession object
            %           XNATSession object instance with jsessionid and
            %           host set.
            %
            %       project :: string
            %           XNAT project name (ex. ABC01_CMH)
            %
            %       experiment :: string
            %           XNAT Experiment name.
            %           (ex. ABC01_CMH_00001_01_SE01_MR)
            %
            %
            % Return:
            %       expr_cell :: struct
            %           a single experiment struct.
            %
            experiments = obj.get_experiments(project, subject);
            index_vec = cellfun(@(e) isequal(e.label, experiment), experiments);
            expr_cell = experiments{find(index_vec)};
        end
        
        function subjects = get_subjects(obj, project)
            % Return a cell array of structs with subjects data
            %
            % Args:
            %       obj :: XNATSession object
            %           XNATSession object instance with jsessionid and
            %           host set.
            %
            %       project :: string
            %           XNAT project name. (ex. ABC01_CMH))
            %
            % Return:
            %       subjects :: {structs}
            %           A cell array with each element a scan structure.
            %
            path = ['/data/projects/' project '/subjects' ];
            query = {'format', 'json'};
            
            % Check if it exists
            resp = request_(obj, 'GET', path, query );
            
            if obj.debug
                resp
            end
            % Get the scan index and return a cell array of scan data
            subjects = num2cell(resp.ResultSet.Result);
        end
        
        function resp = create_experiment(obj, project, subject, ...
                                              experiment, datatype )
            % Return http response from GET request
            %
            % Args:
            %       obj :: XNATSession object
            %           XNATSession object instance with jsessionid and
            %           host set.
            %
            %       project :: string
            %           XNAT project name (ex. ABC01_CMH)
            %
            %       subject :: string
            %           XNAT subject name.
            %           (ex. ABC01_CMH_00001)
            %
            %       experiment :: string
            %           XNAT Experiment name.
            %           (ex. ABC01_CMH_00001_01_SE01_MR)
            %       
            %       datatype :: string
            %           Type of experiment to create. Options: [mr, eeg,
            %           pet]
            %
            % Return:
            %       resp :: string
            %           The XNAT experiment ID if successful, empty string
            %           if not
            %
            
            % Check that the datatype is appropriate
            if not(XNATSession.check_datatype(datatype))
                disp(['Datatype: ' datatype ' is not appropriate']);
                resp = '';
                return;
            end
            
            path = ['/data/projects/' project '/subjects/' subject ...
                     '/experiments/' experiment];
                 
            query = {'xsiType', ['xnat:' datatype 'SessionData']};
                
            % Check if experiment exists
            exprs = get_experiments(obj, project, subject);
            expr_labels = cellfun(@(e) e.label, exprs, ...
                                    'UniformOutput', false);
                                
            if any(strcmp(expr_labels, experiment))
                disp(['The experiment: ' experiment ' exists already']);
                resp = '';
            else
                % Create Experiment
                resp = request_(obj, 'PUT', path, query );
            end
 
        end
        
        function resp = delete_experiment(obj, project, subject, ...
                                                  experiment )
                % Delete an experiment on XNAT
                %
                % Args:
                %       obj :: XNATSession object
                %           XNATSession object instance with jsessionid and
                %           host set.
                %
                %       project :: string
                %           XNAT project name (ex. ABC01_CMH)
                %
                %       subject :: string
                %           XNAT subject name.
                %           (ex. ABC01_CMH_00001)
                %
                %       experiment :: string
                %           XNAT Experiment name.
                %           (ex. ABC01_CMH_00001_01_SE01_MR)
                %       
                %
                % Return:
                %       resp :: vector
                %           0×1 empty uint8 column vector if successful
                %

                path = ['/data/projects/' project '/subjects/' subject ...
                         '/experiments/' experiment];

                % Check if experiment exists
                exprs = get_experiments(obj, project, subject);
                expr_labels = cellfun(@(e) e.label, exprs, ...
                                        'UniformOutput', false);

                if not(XNATSession.exists(expr_labels, experiment))
                    disp(['The experiment: ' experiment ' does not exist']);
                    resp = '';
                else
                    % Create Experiment
                    resp = request_(obj, 'DELETE', path, {} );
                end

        end
        function resp = create_scan(obj, project, subject, experiment,...
                                               scan, datatype)
            % Return http response from GET request
            %
            % Args:
            %       obj :: XNATSession object
            %           XNATSession object instance with jsessionid and
            %           host set.
            %
            %       project :: string
            %           XNAT project name (ex. ABC01_CMH)
            %
            %       subject :: string
            %           XNAT subject name.
            %           (ex. ABC01_CMH_00001)
            %
            %       experiment :: string
            %           XNAT Experiment name.
            %           (ex. ABC01_CMH_00001_01_SE01_MR)
            %       
            %       scan :: string
            %           XNAT scan name.
            %           (ex. '0')
            %
            %       datatype :: string
            %           XNAT xsiType. Must be chosen from [mr, pet, eeg]
            %           (ex. ABC01_CMH_00001)
            %
            % Return:
            %       resp :: string
            %           The XNAT experiment ID if successful, empty string
            %           if not
            %
            
            % Check that the datatype is appropriate
                        
            path = ['/data/projects/' project '/subjects/' subject ...
                     '/experiments/' experiment '/scans/' scan];
                 
            query = {'xsiType', ['xnat:' datatype 'ScanData']};
                
            % Check if experiment exists
            scans = get_scans(obj, project, experiment);
            scan_labels = cellfun(@(s) s.ID, scans, ...
                                    'UniformOutput', false);
                                
            if XNATSession.exists(scan_labels, scan)
                disp(['The scan: ' scan ' exists already']);
                resp = '';
            else
                % Create Experiment
                resp = request_(obj, 'PUT', path, query );
            end
 
        end
        function resp = delete_scan(obj, project, subject, experiment,...
                                                  scan )
            % Delete an experiment on XNAT
            %
            % Args:
            %       obj :: XNATSession object
            %           XNATSession object instance with jsessionid and
            %           host set.
            %
            %       project :: string
            %           XNAT project name (ex. ABC01_CMH)
            %
            %       subject :: string
            %           XNAT subject name.
            %           (ex. ABC01_CMH_00001)
            %
            %       experiment :: string
            %           XNAT Experiment name.
            %           (ex. ABC01_CMH_00001_01_SE01_MR)
            %       
            %       scan :: string
            %           XNAT scan name.
            %           (ex. '0')
            %
            % Return:
            %       resp :: vector
            %           0×1 empty uint8 column vector if successful
            %

            path = ['/data/projects/' project '/subjects/' subject ...
                 '/experiments/' experiment '/scans/' scan];

            % Check if experiment exists
            scans = get_scans(obj, project, experiment);
            scan_labels = cellfun(@(s) s.ID, scans, ...
                                    'UniformOutput', false);

            if not(XNATSession.exists(scan_labels, scan))
                disp(['The scan: ' scan ' exists already']);
                resp = '';
            else
                % Create Experiment
                resp = request_(obj, 'DELETE', path, {} );
            end

        end
        
        function resp = create_resource(obj, project, subject, experiment,...
                                               scan, resource)
            % Create a scan resource folder
            %
            % Args:
            %       obj :: XNATSession object
            %           XNATSession object instance with jsessionid and
            %           host set.
            %
            %       project :: string
            %           XNAT project name (ex. ABC01_CMH)
            %
            %       subject :: string
            %           XNAT subject name.
            %           (ex. ABC01_CMH_00001)
            %
            %       experiment :: string
            %           XNAT Experiment name.
            %           (ex. ABC01_CMH_00001_01_SE01_MR)
            %       
            %       scan :: string
            %           XNAT scan name.
            %           (ex. '0')
            %
            %       resource :: string
            %           XNAT resrouce folder label
            %           (ex. DICOM, or EEG)
            %
            % Return:
            %       resp :: string
            %           The XNAT experiment ID if successful, empty string
            %           if not
            %
            
            % Check that the datatype is appropriate
                        
            path = ['/data/projects/' project '/subjects/' subject ...
                     '/experiments/' experiment '/scans/' scan ...
                     '/resources/' resource];
            query = {'format', 'json'};
                 
            % Check if experiment exists
            resources = get_resources(obj, project, subject, experiment, scan);
            res_labels = cellfun(@(r) r.label, resources, ...
                                    'UniformOutput', false);
                                
            if XNATSession.exists(res_labels, resource)
                disp(['The resource: ' resrource ' exists already']);
                resp = '';
            else
                % Create Experiment
                resp = request_(obj, 'PUT', path, query );
            end
 
        end
        
        function resp = delete_resource(obj, project, subject, ... 
                                    experiment, scan, resource )
            % Delete a scan resource on XNAT
            %
            % Args:
            %       obj :: XNATSession object
            %           XNATSession object instance with jsessionid and
            %           host set.
            %
            %       project :: string
            %           XNAT project name (ex. ABC01_CMH)
            %
            %       subject :: string
            %           XNAT subject name.
            %           (ex. ABC01_CMH_00001)
            %
            %       experiment :: string
            %           XNAT Experiment name.
            %           (ex. ABC01_CMH_00001_01_SE01_MR)
            %       
            %       scan :: string
            %           XNAT scan name.
            %           (ex. '0')
            %
            %       resource :: string
            %           XNAT resrouce name.
            %           (ex. DICOM, or EEG)
            %
            % Return:
            %       resp :: vector
            %           0×1 empty uint8 column vector if successful
            %

            path = ['/data/projects/' project '/subjects/' subject ...
                     '/experiments/' experiment '/scans/' scan ...
                     '/resources/' resource];

           % Check if experiment exists
            resources = get_resources(obj, project, subject, experiment, scan);
            res_labels = cellfun(@(r) r.label, resources, ...
                                    'UniformOutput', false);
                                
            if not(XNATSession.exists(res_labels, resource))
                disp(['The resource: ' resource ' does not exist']);
                resp = '';
            else
                % Create Experiment
                resp = request_(obj, 'DELETE', path, {} );
            end

        end
        
        function resp = upload_file(obj, project, subject, experiment,...
                                     scan, resource, local_file, ...
                                     filename, query)
            % Create a scan resource folder
            %
            % Args:
            %       obj :: XNATSession object
            %           XNATSession object instance with jsessionid and
            %           host set.
            %
            %       project :: string
            %           XNAT project name (ex. ABC01_CMH)
            %
            %       subject :: string
            %           XNAT subject name.
            %           (ex. ABC01_CMH_00001)
            %
            %       experiment :: string
            %           XNAT Experiment name.
            %           (ex. ABC01_CMH_00001_01_SE01_MR)
            %       
            %       scan :: string
            %           XNAT scan name.
            %           (ex. '0')
            %
            %       resource :: string
            %           XNAT resrouce folder label
            %           (ex. DICOM, or EEG)
            %
            %       local_file :: string
            %           Path to local file
            %           (ex. DICOM, or EEG)
            %
            % Return:
            %       resp :: string
            %           The XNAT experiment ID if successful, empty string
            %           if not
            %
            
            % Check that the datatype is appropriate
                        
            path = ['/data/projects/' project '/subjects/' subject ...
                     '/experiments/' experiment '/scans/' scan ...
                     '/resources/' resource '/files/' filename];
            query = [query, {'inbody', 'true'}];
            
            path = XNATSession.construct_url(path, query);
            
            headers = {'Content-Type', 'application/octet-stream'};
            
            try
                fid = fopen(local_file, 'r');
                data = char(fread(fid)');
                fclose(fid);
            catch ME
                disp(ME.identifier)
                disp(['File ' local_file ' cannot be opened'])
            end
            
            % Check if experiment exists
            files = get_files(obj, project, subject, experiment, scan);
            file_labels = cellfun(@(f) f.Name, files, ...
                                    'UniformOutput', false);
            if XNATSession.exists(file_labels, filename)
                disp(['The file: ' filename ' exists already']);
                resp = '';
            else
                % Create Experiment
                resp = request_(obj, 'PUT', path, query, data, headers );
            end
 
        end
        
        function resp = delete_file(obj, project, subject, experiment,...
                                                  scan, resource, file )
            % Delete an experiment on XNAT
            %
            % Args:
            %       obj :: XNATSession object
            %           XNATSession object instance with jsessionid and
            %           host set.
            %
            %       project :: string
            %           XNAT project name (ex. ABC01_CMH)
            %
            %       subject :: string
            %           XNAT subject name.
            %           (ex. ABC01_CMH_00001)
            %
            %       experiment :: string
            %           XNAT Experiment name.
            %           (ex. ABC01_CMH_00001_01_SE01_MR)
            %       
            %       scan :: string
            %           XNAT scan name.
            %           (ex. '0')
            %
            % Return:
            %       resp :: vector
            %           0×1 empty uint8 column vector if successful
            %

            path = ['/data/projects/' project '/subjects/' subject ...
                     '/experiments/' experiment '/scans/' scan ...
                     '/resources/' resource '/files/' file];

            % Check if experiment exists
            files = get_files(obj, project, subject, experiment, scan);
            file_labels = cellfun(@(s) s.Name, files, ...
                                    'UniformOutput', false);

            if not(XNATSession.exists(file_labels, file)) 
                disp(['The file: ' file ' doesnt exist ']);
                resp = '';
            else
                % Create Experiment
                resp = request_(obj, 'DELETE', path, {} );
            end

        end
        function resp = set_attribute(obj, project, subject, experiment,...
                                     attribute, value, varargin)
            % Set an experiment or scan attribute
            %
            % Args:
            %       obj :: XNATSession object
            %           XNATSession object instance with jsessionid and
            %           host set.
            %
            %       project :: string
            %           XNAT project name (ex. ABC01_CMH)
            %
            %       subject :: string
            %           XNAT subject name.
            %           (ex. ABC01_CMH_00001)
            %
            %       experiment :: string
            %           XNAT Experiment name.
            %           (ex. ABC01_CMH_00001_01_SE01_MR)
            %       
            %       scan :: string
            %           XNAT scan name.
            %           (ex. '0')
            %
            %       attribute :: string
            %           The XNAT object metadata attribute to change
            %           (https://wiki.xnat.org/display/XAPI/XNAT+REST+XML+Path+Shortcuts)
            %           (ex. type, or date, series_description)
            %
            %       value :: string
            %           Tha velue to which the attribute will change
            %           
            %
            % Return:
            %       resp :: string
            %           The XNAT experiment ID if successful, empty string
            %           if not
            %
            
            
            
            path = ['/data/projects/' project '/subjects/' subject ...
                     '/experiments/' experiment];
            % get the datatype
            if isequal(nargin, 7)
                scan = varargin{1};
                path = [path '/scans/' scan];
                s = obj.get_scan(project, subject, experiment, scan);
                datatype = s.xsi_type;
            else
                e = obj.get_experiment(project, subject, experiment);
                datatype = e.xsiType;
            end
            
            % '/data/projects/TST01_CMH/subjects/TST01_CMH_0001/experiments/TST01_CMH_0001_01_SE01_MR/scans/3?xsiType=xnat:mrScanData&type=SAG T2 frFSE'
            query = {'xsiType', datatype, attribute, value};
                      
            resp = request_(obj, 'PUT', path, query);
 
        end
        function resp = upload_eeg(obj, project, subject, experiment,...
                                     scan, task, local_file, ...
                                     filename, query)
            % Upload EEG File
            %
            % Args:
            %       obj :: XNATSession object
            %           XNATSession object instance with jsessionid and
            %           host set.
            %
            %       project :: string
            %           XNAT project name (ex. ABC01_CMH)
            %
            %       subject :: string
            %           XNAT subject name.
            %           (ex. ABC01_CMH_00001)
            %
            %       experiment :: string
            %           XNAT Experiment name.
            %           (ex. ABC01_CMH_00001_01_SE01_MR)
            %       
            %       scan :: string
            %           XNAT scan name.
            %           (ex. '0')
            %
            %       task :: string
            %           Task name performed during eeg. (ex. rest)
            %
            %       local_file :: string
            %           Path to local file
            %           (ex. DICOM, or EEG)
            %
            % Return:
            %       resp :: string
            %           The XNAT experiment ID if successful, empty string
            %           if not
            %                     
            obj.upload_file(project, subject, experiment,...
                            scan, 'EEG', local_file, ...
                            filename, query)
            obj.set_attribute(project, subject, experiment, 'type',...
                                task, scan)
            
            %TODO
            %figure out how to extract the scan data and set attribute
        end
        
        function fname = download_eeg(obj, project, subject, experiment,...
                                     scan, filename)
            % Download EEG data from XNAT
            %
            % Args:
            %       obj :: XNATSession object
            %           XNATSession object instance with jsessionid and
            %           host set.
            %
            %       project :: string
            %           XNAT project name (ex. ABC01_CMH)
            %
            %       subject :: string
            %           XNAT subject name.
            %           (ex. ABC01_CMH_00001)
            %
            %       experiment :: string
            %           XNAT Experiment name.
            %           (ex. ABC01_CMH_00001_01_SE01_MR)
            %       
            %       scan :: string
            %           XNAT scan name.
            %           (ex. '0')
            %
            %       filename :: string
            %           Path to local file to save to.
            %           
            %
            % Return:
            %       fname :: string
            %           Path to newly downloaded file
            %
            
            files = obj.get_files(project, subject, experiment, scan);
            index_vec = cellfun(@(f) isequal(f.collection, 'EEG'), files);
            files_filt = files(find(index_vec));
            
            if obj.debug
                disp(['Downloading ' length(files_filt) ' files']);
            end
            
            if length(files_filt) > 1
                disp(['Too many files, ignoring filename and using xnat' ...
                    'filename']);
            end
            
            options = weboptions('RequestMethod', 'GET', ...
                              'KeyName', 'cookie', ...
                              'KeyValue', ['JSESSIONID=', obj.jsessionid],...
                              'Timeout', 60);

            for i = 1:length(files_filt)
                path = ['/data/projects/' project '/subjects/' subject ...
                         '/experiments/' experiment '/scans/' scan ...
                         '/resources/EEG/files/' files_filt{i}.Name];
                     
                tmp_filename = filename;
                if length(files_filt) > 1
                    tmp_filename = files_filt{i}.Name;
                end
                
                fname = websave(tmp_filename, strcat(obj.host, path), ...
                                options);

            end
        end
            
        function fname = download_dcm(obj, project, subject, experiment,...
                                     scan, zipname)
            % Download MRI/PET (dicom) data
            %
            % Args:
            %       obj :: XNATSession object
            %           XNATSession object instance with jsessionid and
            %           host set.
            %
            %       project :: string
            %           XNAT project name (ex. ABC01_CMH)
            %
            %       subject :: string
            %           XNAT subject name.
            %           (ex. ABC01_CMH_00001)
            %
            %       experiment :: string
            %           XNAT Experiment name.
            %           (ex. ABC01_CMH_00001_01_SE01_MR)
            %       
            %       scan :: string
            %           XNAT scan name.
            %           (ex. '0')
            %
            %       zipname :: string
            %           Path to local file to save to.
            %           
            %
            % Return:
            %       fname :: string
            %           Path to newly downloaded file
            %
            
            %/data/projects/TEST/subjects/1/experiments/MR1/scans/1/files?format=zip
            options = weboptions('RequestMethod', 'GET', ...
                              'KeyName', 'cookie', ...
                              'KeyValue', ['JSESSIONID=', obj.jsessionid],...
                              'Timeout', 60);

            path = ['/data/projects/' project '/subjects/' subject ...
                     '/experiments/' experiment '/scans/' scan ...
                     '/resources/DICOM/files'];
            query = {'format', 'zip'};
            
            url = XNATSession.construct_url(path, query);

            fname = websave(zipname, strcat(obj.host, url), options);

        end    
    end
    
    methods (Static)
        
        function index = find_index(struct_, string_)
            % example:
            %  struct_ = {resp.items.children.field}
            %
            % This would find the field that matches the string given the 3
            % children
            
            index = find(contains(struct_, string_)==1);
        end
        
        function ok = check_datatype(datatype)
            % Check that the datatype is an acceptable XNAT type
            datatypes = {'mr', 'pet', 'eeg'};
            ok = exists(datatypes, datatype)
        end
        
        function exists = exists(list, object)
            % check the list (cell array of strings) for the existence of
            % the object ( a string) 
            if any(strcmp(list, object))
                exists = true;
            else
                exists = false;
            end
        end
        
        function path = construct_url(path, query)
            % Add the query parameters to the url path
            if ~isempty(query)
                path = [path '?'];
                for i = 1:2:length(query)
                    path = [path query{i} '=' query{i+1} '&'];
                end
                path = strip(path, 'right', '&');
            end      
        end
        
        function password = get_password(user, password, pass_file)
            % Return users password
            if not(isempty(pass_file)) && isempty(password)
                fid = fopen(pass_file);
                password_cell = textscan(fid, '%s');
                c = fclose(fid);
                password = password_cell{1}{1};
            elseif isempty(password) && isempty(pass_file)
                [u,password] = XNATSession.get_authentication(user);
            end
            
        end
        
        
        function [username, mypass] = get_authentication(defaultuser)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %GetAuthentication prompts a username and password from a user and hides the
            % password input by *****
            %
            %   [user,password] = GetAuthentication;
            %   [user,password] = GetAuthentication(defaultuser);
            %
            % arguments:
            %   defaultuser - string for default name
            %
            % results:
            %   username - string for the username
            %   password - password as a string
            %
            % Created by Felix Ruhnow, MPI-CBG Dresden
            % Version 1.00 - 20th February 2009
            %
            % Modified by Jay Hennessy, 22 Aug 2019
            %
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if nargin==0
                defaultuser='';
            end

            hAuth.fig = figure('Menubar','none','Units','normalized','Resize','off','NumberTitle','off', ...
                               'Name','Authentication','Position',[0.4 0.4 0.2 0.2],'WindowStyle','normal');
            uicontrol('Parent',hAuth.fig,'Style','text','Enable','inactive','Units','normalized','Position',[0 0 1 1], ...
                      'FontSize',11);

            uicontrol('Parent',hAuth.fig,'Style','text','Enable','inactive','Units','normalized','Position',[0.1 0.8 0.8 0.1], ...
                                  'FontSize',11,'String','Username:','HorizontalAlignment','left');


            hAuth.eUsername = uicontrol('Parent',hAuth.fig,'Style','edit','Tag','username','Units','normalized','Position',[0.1 0.675 0.8 0.125], ...
                                   'FontSize',11,'String',defaultuser,'BackGroundColor','white','HorizontalAlignment','left');

            uicontrol('Parent',hAuth.fig,'Style','text','Enable','inactive','Units','normalized','Position',[0.1 0.5 0.8 0.1], ...
                      'FontSize',11,'String','Password:','HorizontalAlignment','left');

            hAuth.ePassword = uicontrol('Parent',hAuth.fig,'Style','edit','Tag','password','Units','normalized','Position',[0.1 0.375 0.8 0.125], ...
                                        'FontSize',11,'String','','BackGroundColor','white','HorizontalAlignment','left');                   

            uicontrol('Parent',hAuth.fig,'Style','pushbutton','Tag','OK','Units','normalized','Position',[0.1 0.05 0.35 0.2], ...
                                        'FontSize',11,'String','OK','Callback','uiresume;');                   

            uicontrol('Parent',hAuth.fig,'Style','pushbutton','Tag','Cancel','Units','normalized','Position',[0.55 0.05 0.35 0.2], ...
                                        'FontSize',11,'String','Cancel','Callback',@AbortAuthentication);                                           
            set(hAuth.fig,'CloseRequestFcn',@AbortAuthentication)
            set(hAuth.ePassword,'KeypressFcn',@PasswordKeyPress)
            setappdata(0,'hAuth',hAuth);
            uicontrol(hAuth.eUsername);
            uiwait;
            username = get(hAuth.eUsername,'String');
            mypass = get(hAuth.ePassword,'UserData');
            delete(hAuth.fig);

                function PasswordKeyPress(hObject,event)
                    hAuth = getappdata(0,'hAuth');
                    mypass = get(hAuth.ePassword,'UserData');
                    switch event.Key
                       case 'backspace'
                          mypass = mypass(1:end-1);
                       case 'return'
                          uiresume;
                          return;
                       otherwise
                          mypass = [mypass event.Character];
                    end
                    set(hAuth.ePassword,'UserData',mypass)
                    set(hAuth.ePassword,'String',char('*'*sign(mypass)))
                end

                function AbortAuthentication(hObject,event)
                    hAuth = getappdata(0,'hAuth');
                    set(hAuth.eUsername,'String','');
                    set(hAuth.ePassword,'UserData','');
                    uiresume;
                end
            end
    end
    
    
end

function b = append_struct(a, b)
    % Append two structures
    f = fieldnames(a);
    for i=1:length(f)
        b.(f{i}) = a.(f{i});
    end
end
