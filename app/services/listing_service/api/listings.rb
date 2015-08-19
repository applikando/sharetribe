module ListingService::API
  ListingStore = ListingService::Store::Listing

  QueryParams = EntityUtils.define_builder(
    [:listing_shape_id, :fixnum],
    [:open, :bool]
  )

  Search = EntityUtils.define_builder(
    [:community_id, :fixnum, :mandatory],
    [:keywords, :string, :mandatory] # TODO Shouldn't be mandatory
  )

  class Listings

    def search(community_id:, search:)
      search_params = Search.call(search.merge(community_id: community_id))

      conn = Faraday.new(:url => "http://sharetribe-search.herokuapp.com") do |c|
        c.request  :url_encoded             # form-encode POST params
        c.response :logger                  # log requests to STDOUT
        c.response :json                    # Parse JSON response

        c.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end

      begin
        Result::Success.new(conn.get('/search', search_params).body)
      rescue StandardError => e
        Result::Error.new(e)
      end
    end

    def count(community_id:, query: {})
      q = HashUtils.compact(QueryParams.call(query))
      Result::Success.new(
        ListingStore.count(community_id: community_id, query: q))
    end

    def update_all(community_id:, query: {}, opts: {})
      find_opts = {
        community_id: community_id,
        query: query
      }

      Maybe(ListingStore.update_all(find_opts.merge(opts: opts))).map {
        Result::Success.new()
      }.or_else {
        Result::Error.new("Can not find listings #{find_opts}")
      }
    end
  end
end
