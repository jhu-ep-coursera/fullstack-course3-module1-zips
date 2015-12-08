module ZipsHelper
  def toZip(value)
    #change value to a Zip if not already a Zip       
    return value.is_a?(Zip) ? value : Zip.new(value)
  end
end
