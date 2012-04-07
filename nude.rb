require 'rmagick'
=begin
 * Nude.js - Nudity detection with Javascript and HTMLCanvas
 * 
 * Author: Patrick Wied ( http:#www.patrick-wied.at )
 * Version: 0.1  (2010-11-21)
 * License: MIT License
=end
class Nude
  attr_accessor :skin_regions, :skin_map, :image, :result

  def inspect
    "#{@image} #{@result}"
  end

  def initialize(file_path, scan_immediately = true)
    @skin_regions = []
    @skin_map = []
    @image = Magick::Image.read(file_path).first
    
    scan_image if scan_immediately
  end








  def scan_image
    detectedRegions = []
    mergeRegions = []
    width = @image.columns
    lastFrom = -1
    lastTo = -1

    # iterate the image from the top left to the bottom right
    width = @image.columns

    @image.rows.times do |y|
      @image.columns.times do |x|
        pixel = @image.pixel_color(x, y)
        r = pixel.red / 256; b = pixel.blue / 256; g = pixel.green / 256
        #r = pixel.red; b = pixel.blue; g = pixel.green
        u = 1 + y * @image.columns + x
        #puts "Handling pixel #{x} #{y} with rgb #{r}/#{g}/#{b}"
        
        if(classifySkin(r, g, b))
          #puts "YES for #{u}"
          @skin_map.push({id: u, skin: true, region: 0, x: x, y: y, checked: false})
          
          region = -1
          checkIndexes = [u-2, (u-width)-2, u-width-1, (u-width)]
          checker = false
          
          4.times do |o|
            index = checkIndexes[o]
            if(@skin_map[index] && @skin_map[index][:skin])
              if(@skin_map[index][:region] != region && region != -1 && lastFrom != region && lastTo != @skin_map[index][:region])
                #addMerge(region, @skin_map[index][:region])
                from = region
                to = @skin_map[index][:region]
                lastFrom = from
                lastTo = to
                len = mergeRegions.length
                fromIndex = -1
                toIndex = -1
                
                
                len.times do |i|
                
                  lregion = mergeRegions[i]
                  rlen = lregion.length
                  
                  rlen.times do |o|
                  
                    if(lregion[o] == from)
                      fromIndex = i
                    end
                    
                    if(lregion[o] == to)
                      toIndex = i
                    end
                                
                  end
                  
                end

                if(fromIndex != -1 && toIndex != -1 && fromIndex == toIndex)
                  
                elsif(fromIndex == -1 && toIndex == -1)
                  mergeRegions.push([from, to])
                  
                elsif(fromIndex != -1 && toIndex == -1)
                  mergeRegions[fromIndex].push(to)
                  
                elsif(fromIndex == -1 && toIndex != -1)
                  mergeRegions[toIndex].push(from)
                  
                elsif(fromIndex != -1 && toIndex != -1 && fromIndex != toIndex)
                  mergeRegions[fromIndex] = mergeRegions[fromIndex].concat(mergeRegions[toIndex])
                  mergeRegions.slice!(toIndex)
                  
                end
              end

              region = @skin_map[index][:region]
              checker = true
            end
          end

          if(!checker)
            @skin_map[u-1][:region] = detectedRegions.length
            detectedRegions.push([@skin_map[u-1]])
            next
          else
            
            if(region > -1)
              
              if(!detectedRegions[region])
                detectedRegions[region] = []
              end

              @skin_map[u-1][:region] = region         
              detectedRegions[region].push(@skin_map[u-1])

            end
          end
          
        else
          #puts "no for #{u}"
          @skin_map.push({id: u, skin: false, region: 0, x: x, y: y, checked: false})
        end

      end
    end

    merge(detectedRegions, mergeRegions)
    @result = analyseRegions()
    return @result
  end

  # function for merging detected regions
  def merge(detectedRegions, mergeRegions)

    length = mergeRegions.length
    detRegions = []


    # merging detected regions 
    length.times do |i|
      
      region = mergeRegions[i]
      rlen = region.length

      if(!detRegions[i])
        detRegions[i] = []
      end

      rlen.times do |o|
        index = region[o]
        detRegions[i] = detRegions[i].concat(detectedRegions[index])
        detectedRegions[index] = []
      end

    end

    # push the rest of the regions to the detRegions array
    # (regions without merging)
    l = detectedRegions.length
    (l-1).downto(0) do |i|
      if(detectedRegions[i].length > 0)
        detRegions.push(detectedRegions[i])
      end
    end

    # clean up
    clearRegions(detRegions)

  end

  # clean up function
  # only pushes regions which are bigger than a specific amount to the final result
  def clearRegions(detectedRegions)

    length = detectedRegions.length

    length.times do |i|
      if(detectedRegions[i].length > 30)
        @skin_regions.push(detectedRegions[i])
      end
    end

  end

  def analyseRegions
    puts "analysing regions"

    # sort the detected regions by size
    length = @skin_regions.length
    totalPixels = (@image.columns * @image.rows).to_f
    totalSkin = 0.0

    # if there are less than 3 regions
    if(length < 3)
      puts "It's not nude :) - less than 3 skin regions (#{length})"
      return false
    end

    # sort the @skin_regions with bubble sort algorithm
    sorted = false
    while(!sorted) do
      sorted = true
      (length-1).times do |i|
        if(@skin_regions[i].length < @skin_regions[i+1].length)
          sorted = false
          temp = @skin_regions[i]
          @skin_regions[i] = @skin_regions[i+1]
          @skin_regions[i+1] = temp
        end
      end
    end

    # count total skin pixels
    (length-1).downto(0) do |i|
      totalSkin += @skin_regions[i].length
    end

    # check if there are more than 15% skin pixel in the image
    if((totalSkin / totalPixels) * 100 < 15)
      # if the percentage lower than 15, it's not nude!
      puts "it's not nude :) - total skin percent is #{totalSkin / totalPixels * 100} %"
      return false
    end


    # check if the largest skin region is less than 35% of the total skin count
    # AND if the second largest region is less than 30% of the total skin count
    # AND if the third largest region is less than 30% of the total skin count
    if((@skin_regions[0].length / totalSkin) * 100 < 35 && (@skin_regions[1].length / totalSkin) * 100 < 30 && (@skin_regions[2].length / totalSkin) * 100 < 30)
      # the image is not nude.
      puts "it's not nude :) - less than 35%,30%,30% skin in the biggest areas :"
      3.times do |i|
        puts "  #{@skin_regions[0].length / totalSkin * 100}%"
      end

      return false
    end

    # check if the number of skin pixels in the largest region is less than 45% of the total skin count
    if((@skin_regions[0].length / totalSkin) * 100 < 45)
      # it's not nude
      puts "it's not nude :) - the biggest region contains less than 45%: #{@skin_regions[0].length / totalSkin * 100}%"
      return false
    end

    # TODO:
    # build the bounding polygon by the regions edge values:
    # Identify the leftmost, the uppermost, the rightmost, and the lowermost skin pixels of the three largest skin regions.
    # Use these points as the corner points of a bounding polygon.

    # TODO:
    # check if the total skin count is less than 30% of the total number of pixels
    # AND the number of skin pixels within the bounding polygon is less than 55% of the size of the polygon
    # if this condition is true, it's not nude.

    # TODO: include bounding polygon functionality
    # if there are more than 60 skin regions and the average intensity within the polygon is less than 0.25
    # the image is not nude
    if(@skin_regions.length > 60)
      puts "it's not nude :) - more than 60 skin regions"
      return false
    end


    # otherwise it is nude
    return true
  end

  def classifySkin(r, g, b)
    # A Survey on Pixel-Based Skin Color Detection Techniques
    rgbClassifier = ((r > 95) && (g > 40 && g < 100) && (b > 20) && (([r,g,b].max - [r,g,b].min) > 15) && ((r-g).abs > 15) && (r > g) && (r > b))
    nurgb = toNormalizedRgb(r, g, b)
    #puts nurgb.inspect
    nr = nurgb[0]
    ng = nurgb[1]
    nb = nurgb[2]
    normRgbClassifier = (((nr/ng)>1.185) && (((r*b)/((r+g+b) ** 2).to_f) > 0.107) && (((r*g)/((r+g+b) ** 2).to_f) > 0.112))
    #hsv = toHsv(r, g, b),
    #h = hsv[0]*100,
    #s = hsv[1],
    #hsvClassifier = (h < 50 && h > 0 && s > 0.23 && s < 0.68);
    hsv = toHsvTest(r, g, b)
    h = hsv[0]
    s = hsv[1]
    hsvClassifier = (h > 0 && h < 35 && s > 0.23 && s < 0.68)
=begin
     * ycc doesnt work
     
    ycc = toYcc(r, g, b),
    y = ycc[0],
    cb = ycc[1],
    cr = ycc[2],
    yccClassifier = ((y > 80) && (cb > 77 && cb < 127) && (cr > 133 && cr < 173));
=end
    
    #puts "#{r}/#{g}/#{b} #{rgbClassifier}/#{normRgbClassifier}/#{hsvClassifier}"
    return (rgbClassifier || normRgbClassifier || hsvClassifier)
  end

  def toYcc(r, g, b)
    r /= 255; g /= 255; b /= 255
    y = 0.299*r + 0.587*g + 0.114*b
    cr = r - y
    cb = b - y
    
    return [y, cr, cb]
  end

  def toHsv(r, g, b)
    return [
            # hue
            Math.acos((0.5*((r-g)+(r-b)))/(Math.sqrt((((r-g) ** 2)+((r-b)*(g-b)))))),
            # saturation
            1-(3*(([r,g,b].min)/(r+g+b).to_f)),
            # value
            (1/3)*(r+g+b)
            ]
  end

  def toHsvTest(r, g, b)
    h = 0
    mx = [r, g, b].max
    mn = [r, g, b].min
    dif = (mx - mn).to_f
    
    if(mx == r)
      h = (g - b)/dif
    elsif(mx == g)
      h = 2+((g - r)/dif)
    else
      h = 4+((r - g)/dif)
    end

    h *= 60
    if(h < 0)
      h += 360
    end

    return [0, 0, 0] if r+g+b == 0
    
    return [h, 1-(3*(([r,g,b].min)/(r+g+b).to_f)),(1/3)*(r+g+b)]
  end

  def toNormalizedRgb(r, g, b)
    sum = (r+g+b).to_f
    return [(r/sum), (g/sum), (b/sum)]
  end
end


