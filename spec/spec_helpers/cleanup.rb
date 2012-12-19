module ApiPresenter

  def self.clear_collections!
    presenter_collection.presenters.each do |klass, presenter|
      presenter.clear_options!
    end
    @presenter_collection = {}
  end

  class Base
    def self.clear_options!
      @default_sort_order = nil
      @filters = nil
      @sort_orders = nil
    end

    def clear_options!
      self.class.clear_options!
    end
  end

end