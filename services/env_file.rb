module EnvFile
  module_function

  def load(path)
    return unless File.exist?(path)

    File.foreach(path) do |line|
      entry = line.strip
      next if entry.empty? || entry.start_with?("#")

      key, raw_value = entry.split("=", 2)
      next if key.nil? || raw_value.nil?

      ENV[key.strip] ||= normalize_value(raw_value.strip)
    end
  end

  def normalize_value(value)
    return value[1..-2] if value.start_with?('"') && value.end_with?('"') && value.length >= 2
    return value[1..-2] if value.start_with?("'") && value.end_with?("'") && value.length >= 2

    value
  end
end
