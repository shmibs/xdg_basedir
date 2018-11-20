require "./spec_helper"

# NOTE: these tests are non-exhaustive and may fail, as they depend on the
# state of the filesystem and environment
describe XDGBasedir do

  it "finds previously written files using full_path" do
    p = XDGBasedir.full_path "xdg_basedir_test_file_1", :data, "w"
    unless p
      next
    end
    File.write p, "content"

    p = XDGBasedir.full_path "xdg_basedir_test_file_1", :data, "r"
    unless p
      next
    end

    s = File.read p
    f = File.new p
    f.delete

    s.should eq("content")
  end

  it "finds previously written files using dir methods" do
    d = XDGBasedir.write_dir :config
    unless d
      next
    end
    File.write "#{d}xdg_basedir_test_file_2" , "content"

    l = XDGBasedir.read_dirs :config
    unless l
      next
    end

    s = File.read "#{l[0]}xdg_basedir_test_file_2"
    f = File.new "#{d}xdg_basedir_test_file_2"
    f.delete

    s.should eq("content")
  end

  it "fails on bad arguments" do
    expect_raises(ArgumentError) { XDGBasedir.write_dir :bad }
    expect_raises(ArgumentError) { XDGBasedir.read_dirs :bad }
    expect_raises(ArgumentError) { XDGBasedir.full_path "rel_path", :bad }
  end
end
