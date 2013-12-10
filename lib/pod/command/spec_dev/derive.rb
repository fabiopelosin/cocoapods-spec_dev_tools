module Pod
  class Command

    #
    #
    class Derive < SpecDev
      self.summary = "Derives a podspec from an Xcode project"

      self.description = <<-DESC
          Derives a podspec from an Xcode project.
      DESC

      self.arguments = 'PROJECT TARGET'

      def initialize(argv)
        @project = argv.shift_argument
        @target_name = argv.shift_argument
        super
      end

      def validate!
        super
        help! "A project is required." unless @project
        help! "A target is required." unless @target_name
      end

      def run
        target = get_target(@project, @target_name)

        UI.puts
        UI.titled_section("Platform".green) do
          # TODO: add support for config files in Xcodeproj
          # UI.puts "#{target.platform_name} #{target.deployment_target}"
          print_spec_attribute("platform", [:osx, '10.7'])
        end

        UI.puts
        UI.titled_section("Source Files".green) do
          source_files = get_source_files(target)
          print_spec_attribute("source_files", source_files[:globs])
          print_spec_attribute("exclude_files", source_files[:exclusions])
        end

        UI.puts
        UI.titled_section("Public header files".green) do
          public_headers = get_public_headers(target)
          print_spec_attribute("public_header_files", public_headers[:globs])
        end

        UI.puts
        UI.titled_section("Resources".green) do
          resources = get_resources(target)
          print_spec_attribute("resources", resources[:globs])
        end

        UI.puts
        UI.titled_section("System Frameworks".green) do
          system_frameworks = get_system_frameworks(target)
          print_spec_attribute("framework", system_frameworks)
        end

        UI.puts
        UI.titled_section("Dependencies".green) do
          system_frameworks = get_dependencies(target)
          system_frameworks.each do |name|
            UI.puts " - #{name}"
          end
        end
      end

      def print_spec_attribute(attr_name, value)
        text = "s.#{attr_name}  = "
        if value.is_a?(Array)
          return if value.empty?
          if value.count < 4
            text << "#{value.map(&:inspect).join(", ")}"
          else
            text << "[\n  #{value.map(&:inspect).join(",\n  ")}\n]"
          end
        end
        UI.puts text
      end

      public

      # Helpers
      #-----------------------------------------------------------------------#

      #
      #
      def get_target(project_path, target_name)
        require 'Xcodeproj'
        proj = Xcodeproj::Project.open(project_path)
        target = proj.targets.find { |target| target.name == target_name }
        unless target
          raise Pod::Informative, "Unable to find a target named `#{target_name}`."
        end
        target
      end

      #
      #
      def get_system_frameworks(target)
        files_references = target.frameworks_build_phases.files_references
        system_frameworks_refs = files_references.to_a.select do |ref|
          ref.real_path.to_s.include?("/System/Library/Frameworks")
        end
        system_frameworks_refs.map do |ref|
          File.basename(ref.real_path, ".framework")
        end
      end

      #
      #
      def get_dependencies(target)
        files_references = target.frameworks_build_phases.files_references
        dependencies_refs = files_references.to_a.select do |ref|
          !ref.real_path.to_s.include?("/System/Library/Frameworks")
        end
        dependencies_refs.map do |ref|
          File.basename(ref.real_path, ".framework")
        end
      end

      # @return [Hash]
      # TODO: Often the headers are not included in the headers_build_phase
      #
      def get_source_files(target)
        paths = target.source_build_phase.files_references.map(&:real_path)
        paths.concat(target.headers_build_phase.files_references.map(&:real_path))
        suggested_glob_pattern_for_file_list(paths, true, true)
      end

      # @return [Hash]
      #
      def get_public_headers(target)
        public_build_files = target.headers_build_phase.files.select do |build_file|
          settings = build_file.settings || {}
          attributes = settings["ATTRIBUTES"] || []
          attributes.include?("Public")
        end
        paths = public_build_files.map { |bf| bf.file_ref.real_path }
        suggested_glob_pattern_for_file_list(paths)
      end

      def get_resources(target)
        paths = target.resources_build_phase.files_references.map(&:real_path)
        suggested_glob_pattern_for_file_list(paths)
      end

      # @return [Hash]
      # TODO: group by extension and see if all the paths with the extensions
      # are satisfied by a glob.
      #
      def suggested_glob_pattern_for_file_list(paths, allow_exclusions = false, look_for_headers = false)
        globs = []
        exclusion_globs = []

        paths_by_dir = paths.group_by(&:dirname)
        paths_by_dir.each do |dir, paths|
          relative_paths = paths.map { |path| path.relative_path_from(dir) }


          if look_for_headers
            relative_paths = relative_paths.map do |path|
              if path.extname == '.m'
                header_name = File.basename(path, '.m') + '.h'
              elsif path.extname == '.c'
                header_name = File.basename(path, '.c') + '.h'
              end

              header = dir + header_name if header_name
              if header && header.exist?
                [path, path.dirname + header_name]
              else
                path
              end
            end.flatten.uniq
          end

          not_included = dir.entries - relative_paths
          not_included.reject! { |path| path.to_s == '.' || path.to_s == '..' }

          if not_included.count == 0
            globs << "#{relativize(dir)}/*"
          elsif not_included.count < relative_paths.count && allow_exclusions
            globs << "#{relativize(dir)}/*"
            exclusion_globs.concat(relativize(not_included.map {|p| dir + p} ))
          else
            globs.concat(relativize(paths))
          end
        end

        {:globs => globs.map(&:to_s), :exclusions => exclusion_globs.map(&:to_s)}
      end

      # [Array]
      # [Pathname]
      #
      def relativize(paths)
        if paths.is_a?(Pathname)
          paths.relative_path_from(Pathname.pwd)
        else
          paths.map { |p| p.relative_path_from(Pathname.pwd) }
        end
      end


      public

      # Private Helpers
      #-----------------------------------------------------------------------#

      #-------------------------------------------------------------------#

    end
  end
end

