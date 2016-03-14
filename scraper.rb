# require 'active_record'


# ActiveRecord::Base.establish_connection({
#   :adapter => 'postgresql',
#   :host => 'localhost',
#   :database => 'Amf_development'
# })
# < ActiveRecord::Base
#   require 'csv'
#   validates :url, uniqueness: true

class Profile
require 'Mechanize'
require 'Nokogiri'
require 'csv'
require 'pry'
require 'scraperwiki'
# require 'socksify'
# TCPSocket::socks_server = "127.0.0.1"
# TCPSocket::socks_port = 9050

  def self.scraping_profiles
    # num = ARGV[0].to_i
    # max = ARGV[0].to_i + 1000
    num = 0
    while num < 35000
    # while num < max
      @urls = "http://www.amfibi.directory/us/13538-landscape_contractors/#{num}"
      num += 20
      Profile.get_links(@urls, num)
    end
  end

  def self.get_links(urls, num)
    nurl = Hash.new
    company_children = Array.new
    agent = Mechanize.new { |agent| agent.user_agent_alias = "Mac Safari" }
    html = agent.get(urls).links_with search: 'h2 a'
    html.each do |element|
      company_element = element
    nurl[company_element.attributes.values.last] = company_element.attributes.values.first
    end
    Profile.get_profiles(nurl, num)
  end

  def self.get_profiles(nurl, num)
    @nurl = nurl
    @nurl.each do  |key, value|
      @company_name = "#{key}"
      @url = "#{value}"
      begin
        @contact, @alt_contact, @revenue, @employees, @business_yrs, @sic_code, @naics_code, @summary, @email, @address, @city, @state, @zip, @phone, @services, @business_cat = 'NA'
        agents = Mechanize.new { |agent| agent.user_agent_alias = "Mac Safari" }
        html = agents.get(@url).body
        # raw_html = agents.get(@url)
        # html = raw_html.body
        # @state_zip = html.title
        # @zip = @state_zip.gsub(/[^\d-]/, '')
        # @state = ((@state_zip.split(',').last).strip)[0] + ((@state_zip.split(',').last).strip)[1]

      rescue Errno::EHOSTUNREACH
        CSV.open("Errors.csv", "a+") do |csv|
          csv << [@url, "Errno-EHOSTUNREACH"]
        next
        end
      rescue Exception
        CSV.open("Erros.csv", "a+") do |csv|
          csv << [@url, "Exception"]
        next
        end
      end
      doc = Nokogiri::HTML(html)
      Profile.contact(doc)
      Profile.profile(doc)
      Profile.services(doc)
      CSV.open("profilesx.csv", "a+") do |csv|
        csv << [num, @url, @company_name, @address, @city, @state, @zip, @phone, @email, @summary, @contact, @alt_contact, @revenue, @employees, @business_yrs, @business_cat, @services, @sic_code, @naics_code]
      end
    end
  end

  def self.contact(doc)
    begin
      @find_email = doc.xpath("//span[@class = 'cdr']").children.first.text rescue nil
    end
    unless @find_email.nil?
      @email = @find_email.reverse
    end
    # @company_name = ((doc.xpath("//title").children.text).split(/^(.+?),/))[1]
    @contact_info = (doc.xpath("//p")).first
    @address_city = ("#{@contact_info.children.first}").strip
    if @address_city =~ /\d/
      @address = @address_city
      @city = ("#{@contact_info.children[2]}").strip
      @state_zip = ("#{@contact_info.children[4]}").strip
      @state = "#{@state_zip[0]}"+"#{@state_zip[1]}"
      @zip = @state_zip.gsub(/[^\d-]/, '')
      if ("#{@contact_info.children[6]}").gsub(/\D/, "").match(/^1?(\d{3})(\d{3})(\d{4})/)
        @phone = [$1, $2, $3].join("-")
      end
    else
      @city = (@address_city).strip
      @state_zip = ("#{@contact_info.children[2]}").strip
      @state = "#{@state_zip[0]}"+"#{@state_zip[1]}"
      @zip = @state_zip.gsub(/[^\d-]/, '')
      if ("#{@contact_info.children[4]}").gsub(/\D/, "").match(/^1?(\d{3})(\d{3})(\d{4})/)
        @phone = [$1, $2, $3].join("-")
      end
    end
    return @email, @address, @city, @state, @zip, @phone
  end

    def self.profile(doc)
    @doc = doc
    @get_company_profile = doc.xpath("//div[@class='list sub_list']")
    @get_company_profile.each do |company|
      if (company.children.children.to_xml).include? 'Company Representatives'
        @contact = (((company.text).split("\n\n").last.strip!).gsub(/[\s+]/," ").squeeze(' ')).gsub!(/Email.\s+.\S*/, "")
      elsif (company.children.children.to_xml).include? 'More Contacts'
        @alt_contact = (company.text).split(/\s+/).find_all { |u| u =~ /^https?:/ }
      elsif (company.children.children.to_xml).include? 'Revenue'
        @revenue = (company.text).split("\t\t").last.strip!
      elsif  (company.children.children.to_xml).include? 'Employees'
        @employee_format = company.text
        @employee_format.slice! "Employees"
        @employees = (@employee_format.gsub("\t",'')).gsub("\n", '')
      elsif  (company.children.children.to_xml).include? 'Years in Business'
        @business_yrs = (company.text).split("\t\t").last.strip!
      elsif  (company.children.children.to_xml).include? 'SIC Code'
        @sic_code = (company.text).split("\t\n").last.strip!
      elsif (company.children.children.to_xml).include? 'NAICS Code'
        @naics_code = (company.text).split("\t\t").last.strip!
      elsif (company.children.children.to_xml).include? 'About'
        @summary =(company.text).gsub(/[\s+]/," ").squeeze(' ')
      end
    end
    return @contact, @alt_contact, @revenue, @employees, @business_yrs, @sic_code, @naics_code, @summary
  end

  def self.services(doc)
    @doc = doc
    begin
      @get_company_services = doc.xpath("//div[@class='list sub_list cf']") rescue nil
    end
    unless @get_company_services.nil?
      @get_company_services.each do |company|
        if (company.children.children.to_xml).include? 'Products and Services'
          @services = (((company.children.children.text).split("Products and Services\n\t\t\t\t\t\t\t\t\t\t\n\t\t\t\t\t\t\t\t\t\n").last).delete("\t")).gsub(/[\s+,]/,"-")
        elsif (company.children.children.to_xml).include? 'Business categories'
          @business_cat = (((company.children.children.text).split("Business categories\n\t\t\t\t\t\t\t\t\t\t\n\t\t\t\t\t\t\t\t\t\n").last).delete("\t")).gsub(/[\s+,]/,"-")
        end
      end
    end
    return @services, @business_cat
  end
end

Profile.scraping_profiles



