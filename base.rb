module Music
  class Base
    def initialize(options = {})
      @external_urls = options['external_urls']
      @href          = options['href']
      @id            = options['id']
      @type          = options['type']
      @uri           = options['uri']
    end

    def self.search(query, types, limit: 20, offset: 0)
      query = CGI.escape query
      types.gsub!(/\s+/, '')

      url = "search?q=#{query}&type=#{types}"\
              "&limit=#{limit}&offset=#{offset}"

      response = Spotify.get(url)

      types = types.split(',')
      types.flat_map do |type|
        type_class = Spotify.const_get(type.capitalize)
        response.message["#{type}s"]['items'].map { |i| type_class.new i }
      end
    end

    def self.find(ids, type)
      case ids
      when Array
        find_many(ids, type)
      when String
        id = ids
        find_one(id, type)
      end
    end

    def self.find_one(id, type)
      type_class = Spotify.const_get(type.capitalize)
      path = "#{type}s/#{id}"
      response = Spotify.get path
      type_class.new response.message unless response.nil?
    end

    def self.find_many(ids, type)
      type_class = Spotify.const_get(type.capitalize)
      path = "#{type}s?ids=#{ids.join ','}"

      response = Spotify.get path
      response.message["#{type}s"].map { |t| type_class.new t if t }
    end

    def complete!
      initialize Spotify.get("#{@type}s/#{@id}")
    end

    def method_missing(method_name, *args)
      attr = "@#{method_name}"
      return super if method_name.match(/!$/) || !instance_variable_defined?(attr)

      attr_value = instance_variable_get attr
      return attr_value if !attr_value.nil? || @id.nil?

      complete!
      instance_variable_get attr
    end

    def respond_to_missing?(method_name, include_private_methods = false)
      attr = "@#{method_name}"
      return super if method_name.match(/!$/) || !instance_variable_defined?(attr)

      true
    end
  end
end
