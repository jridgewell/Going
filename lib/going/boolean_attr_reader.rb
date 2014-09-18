module Going
  module BooleanAttrReader
    def battr_reader(*attrs)
      attrs.map(&:to_s).each do |attr|
        define_method(attr + '?') do
          !!instance_variable_get('@' + attr)
        end
      end
    end
  end
end
