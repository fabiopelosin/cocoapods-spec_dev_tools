require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Command::Try do

    #-------------------------------------------------------------------------#

    describe "CLAide" do
      it "registers it self" do
        Command.parse(%w{ try }).should.be.instance_of Command::Try
      end

      it "presents the help if no name is provided" do
        command = Pod::Command.parse(['try'])
        should.raise CLAide::Help do
          command.validate!
        end.message.should.match /A Pod name is required/
      end

      it "runs" do
        Config.instance.skip_repo_update = false
        command = Pod::Command.parse(['try', 'ARAnalytics'])
        Installer::PodSourceInstaller.any_instance.expects(:install!)
        command.expects(:update_specs_repos)
        command.expects(:pick_demo_project).returns("/tmp/Proj.xcodeproj")
        command.expects(:open_project).with('/tmp/Proj.xcodeproj')
        command.run
      end
    end

    #-------------------------------------------------------------------------#

    describe "Helpers" do

      before do
        @sut = Pod::Command.parse(['try'])
      end

      it "returns the spec with the given name" do
        spec = @sut.spec_with_name('ARAnalytics')
        spec.name.should == "ARAnalytics"
      end

      it "installs the pod" do
        Installer::PodSourceInstaller.any_instance.expects(:install!)
        spec = stub(:name => 'ARAnalytics')
        path = @sut.install_pod(spec, '/tmp/CocoaPods/Try')
        path.should == Pathname.new("/tmp/CocoaPods/Try/ARAnalytics")
      end

      describe "#pick_demo_project" do
        it "raises if no demo project could be found" do
          projects = []
          Dir.stubs(:glob).returns(projects)
          should.raise Informative do
            @sut.pick_demo_project(stub())
          end.message.should.match /Unable to find any project/
        end

        it "picks a demo project" do
          projects = ['Demo.xcodeproj']
          Dir.stubs(:glob).returns(projects)
          path = @sut.pick_demo_project(stub())
          path.should == "Demo.xcodeproj"
        end

        it "is not case sensitive" do
          projects = ['demo.xcodeproj']
          Dir.stubs(:glob).returns(projects)
          path = @sut.pick_demo_project(stub())
          path.should == "demo.xcodeproj"
        end

        it "considers also projects named example" do
          projects = ['Example.xcodeproj']
          Dir.stubs(:glob).returns(projects)
          path = @sut.pick_demo_project(stub())
          path.should == "Example.xcodeproj"
        end

        it "returns the project if only one is found" do
          projects = ['Lib.xcodeproj']
          Dir.stubs(:glob).returns(projects)
          path = @sut.pick_demo_project(stub())
          path.should == "Lib.xcodeproj"
        end

        it "asks the user which project would like to open if not a single suitable one is found" do
          projects = ['Lib_1.xcodeproj', 'Lib_2.xcodeproj']
          Dir.stubs(:glob).returns(projects)
          @sut.stubs(:choose_from_array).returns(0)
          path = @sut.pick_demo_project(stub(:cleanpath=>''))
          path.should == "Lib_1.xcodeproj"
        end
      end

      describe "#install_podfile" do
        it "returns the original project if no Podfile could be found" do
          Pathname.any_instance.stubs(:exist?).returns(false)
          proj = "/tmp/Project.xcodeproj"
          path = @sut.install_podfile(proj)
          path.should == proj
        end

        it "performs an installation and returns the path of the Podfile" do
          Pathname.any_instance.stubs(:exist?).returns(true)
          proj = "/tmp/Project.xcodeproj"
          @sut.expects(:perform_cocoapods_installation)
          path = @sut.install_podfile(proj)
          path.should == "/tmp/Project.xcworkspace"
        end
      end
    end

    #-------------------------------------------------------------------------#

  end
end
