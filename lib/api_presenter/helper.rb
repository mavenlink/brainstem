module ApiPresenter
  class Helper

    def self.for(namespace)
      @helpers_for ||= {}
      @helpers_for[namespace.to_s] ||= begin
        klass = @helpers[namespace.to_s]
        klass && klass.new
      end
    end

    def self.inherited(subclass)
      names = subclass.name.split("::")
      namespace = names[-2] ? names[-2].downcase : "root"
      @helpers ||= {}
      @helpers[namespace] = subclass
    end

  end
end