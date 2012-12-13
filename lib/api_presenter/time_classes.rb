module ApiPresenter
  class Base
    # This constant stores an array of classes that we will treat as times.
    # Unfortunately, ActiveSupport::TimeWithZone does not descend from
    # Time, so we have to try to put it into this array for later use.
    TIME_CLASSES = [Time]

    begin
      require 'active_support/time_with_zone'
      TIME_CLASSES << ActiveSupport::TimeWithZone
    rescue LoadError
    end
  end
end