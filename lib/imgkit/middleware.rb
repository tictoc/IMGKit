class IMGKit

  class Middleware

    def initialize(app, options = {}, conditions = {})
      @app        = app
      @options    = options
      @conditions = conditions
    end

    def call(env)
      @request    = Rack::Request.new(env)
      @render_image = false

      set_request_to_render_as_image(env) if render_as_image?
      status, headers, response = @app.call(env)

      if rendering_image? && headers['Content-Type'] =~ /text\/html|application\/xhtml\+xml/
        body = response.respond_to?(:body) ? response.body : response.join
        body = body.join if body.is_a?(Array)
        body = IMGKit.new(translate_paths(body, env), @options).to_image
        response = [body]

        # Do not cache images
        headers.delete('ETag')
        headers.delete('Cache-Control')

        headers["Content-Length"]         = (body.respond_to?(:bytesize) ? body.bytesize : body.size).to_s
        headers["Content-Type"]           = "image/jpeg"
      end

      [status, headers, response]
    end

    private

    # Change relative paths to absolute
    def translate_paths(body, env)
      # Host with protocol
      root = IMGKit.configuration.root_url || "#{env['rack.url_scheme']}://#{env['HTTP_HOST']}/"

      body.gsub(/(href|src)=(['"])\/([^\"']*|[^"']*)['"]/, '\1=\2' + root + '\3\2')
    end

    def rendering_image?
      @render_image
    end

    def render_as_image?
      request_path_is_image = @request.path.match(%r{\.jpeg$})

      if request_path_is_image && @conditions[:only]
        rules = [@conditions[:only]].flatten
        rules.any? do |pattern|
          if pattern.is_a?(Regexp)
            @request.path =~ pattern
          else
            @request.path[0, pattern.length] == pattern
          end
        end
      else
        request_path_is_image
      end
    end

    def set_request_to_render_as_image(env)
      @render_image = true
      path = @request.path.sub(%r{\.jpeg$}, '')
      %w[PATH_INFO REQUEST_URI].each { |e| env[e] = path }
      env['HTTP_ACCEPT'] = concat(env['HTTP_ACCEPT'], Rack::Mime.mime_type('.html'))
      env["Rack-Middleware-IMGKit"] = "true"
    end

    def concat(accepts, type)
      (accepts || '').split(',').unshift(type).compact.join(',')
    end

  end
end
