module Import
  class ArtistsAndTracks
    attr_reader :artist_id, :genre, :popular, :import_process

    def initialize(remote_id, popular: false, import_process: nil)
      @artist_id = remote_id
      @popular = popular
      @import_process = import_process
      @retries = 0
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    def call
      remote_artist = Music::Artist.find(artist_id)
      artist = save_artist(remote_artist)
      define_genre(artist)
      albums = remote_artist.albums
      albums.each do |remote_album|
        next if remote_album.album_type == 'compilation' || Album.find_by(remote_id: remote_album.id).present?

        album = save_album(artist, remote_album)
        remote_album.tracks.each { |remote_track| save_track(artist, album, remote_track) }
      end
    rescue NoMethodError => e
      raise unless (@retries += 1) <= 3

      puts "Timeout (#{e}), retrying in #{@retries * 2} second(s)..."
      sleep(@retries * 2)
      retry
    rescue Faraday::ConnectionFailed => e
      raise unless (@retries += 1) <= 3

      puts "Timeout (#{e}), retrying in 10 second(s)..."
      sleep(10)
      retry
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    def save_artist(remote_artist)
      attrs = serialize_artist(remote_artist)
      artist = Artist.find_or_initialize_by(remote_id: attrs[:remote_id])
      artist.update(attrs)
      artist
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    def save_track(artist, album, remote_track)
      attrs = serialize_track(remote_track)
      return if duplicate_exists?(artist, attrs) || !remote_track.artists.map(&:id).include?(artist.remote_id)

      return if attrs[:danceability].nil?

      track = Track.find_or_initialize_by(remote_id: attrs[:remote_id])
      track.artists << artist if track.id.nil?
      track.album = album if track.id.nil?
      track.update(attrs)
      track
    rescue StandardError => e
      puts e
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    def save_album(artist, album)
      attrs = serialize_album(album)
      album = Album.find_or_initialize_by(remote_id: attrs[:remote_id])
      album.artists << artist if album.id.nil?
      album.update(attrs)
      album
    end

    def define_genre(artist)
      @genre = Fields::Genres.call.find_genre(artist.genres)
    end

    def serialize_album(album)
      {
        name: album.name,
        album_type: album.album_type,
        remote_id: album.id
      }
    end

    def serialize_artist(artist)
      attrs = {
        followers: artist.followers['total'],
        name: artist.name,
        popularity: artist.popularity,
        remote_id: artist.id,
        genres: artist.genres,
        popular: popular
      }
      attrs = attrs.merge(import_process_id: import_process.try(:id)) if import_process.present?
      attrs
    end

    # rubocop:disable all
    def serialize_track(track)
      audio_features = track.audio_features
      audio_analysis = track.audio_analysis

      attrs = {
        name: track.name,
        remote_id: track.id,
        acousticness: audio_features.acousticness,
        danceability: audio_features.danceability,
        energy: audio_features.energy,
        instrumentalness: audio_features.instrumentalness,
        key: audio_features.key,
        liveness: audio_features.liveness,
        loudness: audio_features.loudness,
        mode: audio_features.mode,
        speechiness: audio_features.speechiness,
        tempo: audio_features.tempo,
        time_signature: audio_features.time_signature,
        valence: audio_features.valence,
        duration_ms: audio_features.duration_ms,
        genre: genre,
        url: track.external_urls['spotify'],
        popular: popular
      }

      attrs = attrs.merge(TrackAnalysis.new(audio_analysis, track).call) unless attrs[:danceability].nil?
      attrs = attrs.merge(import_process_id: import_process.try(:id)) if import_process.present?
      attrs
    end

    def duplicate_exists?(artist, remote_track)
      return true if artist.tracks.where('lower(name) = ?', remote_track[:name].downcase).first.present?

      feature_params = %w[acousticness danceability energy instrumentalness liveness
                          loudness speechiness time_signature tempo valence]
      query = feature_params.map do |param|
        "#{param}=#{remote_track[param.to_sym]}"
      end.join(' and ')

      duplicate_tracks = Track.where(query)
      duplicate_tracks.each do |duplicate_track|
        if duplicate_track.name.include?(remote_track[:name]) || remote_track[:name].include?(duplicate_track.name)
          return true
        end
      end
      false
    end
  end
end
