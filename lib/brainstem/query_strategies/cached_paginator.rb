class CachedPaginator < Brainstem::QueryStrategies::Paginator

  private

  def get_models(scope)
    get_models_using_ids(scope)
  end

  def get_count(count_scope)

  end


  def get_ids_for_page(scope)
    super
  end
end