class FileSerializer
  def self.save file_name, obj
    File.open(file_name, 'w+') do |f|
      Marshal.dump(obj, f)
    end
  end

  def self.load file_name
    obj = nil
    File.open(file_name) do |f|
      obj = Marshal.load(f)
    end
    obj
  end
end