module ApiPresenter

    TIME_CLASSES = [Time]

    # Unfortunately, we need to use this in a case, but we don't want to
    # require that ActiveSupport be an actual dependency. So we use it if it's there.
    begin
      require 'active_support/time_with_zone'
      TIME_CLASSES << ActiveSupport::TimeWithZone
    rescue LoadError
    end

end