
root = exports ? this

Bubbles = () ->
  # standard variables accessible to
  # the rest of the functions inside Bubbles
  width = 970
  height = 510
  data = []
  node = null
  label = null
  margin = {top: 20, right: 10, bottom: 0, left: 10}
  # largest size for our bubbles
  maxRadius = 65

  # this scale will be used to size our bubbles
  rScale = d3.scale.sqrt().range([0,maxRadius])
  
  # I've abstracted the data value used to size each
  # into its own function. This should make it easy
  # to switch out the underlying dataset
  rValue = (d) -> parseInt(d.count)

  # function to define the 'id' of a data element
  #  - used to bind the data to the force nodes
  #   and for url creation
  #  - should make it easier to switch out dataset
  #   for your own
  idValue = (d) -> d.name

  # function to define what to display in each bubble
  #  again, abstracted to ease migration to 
  #  a different dataset if desired
  textValue = (d) -> d.name

  # constants to control how
  # collision look and act
  collisionPadding = 4
  minCollisionRadius = 12

  # variables that can be changed
  # to tweak how the force layout
  # acts
  # - jitter controls the 'jumpiness'
  #  of the collisions
  jitter = 0.5

  # ---
  # tick callback function will be executed for every
  # iteration of the force simulation
  # - moves force nodes towards their destinations
  # - deals with collisions of force nodes
  # - updates visual bubbles to reflect new force node locations
  # ---
  tick = (e) ->
    dampenedAlpha = e.alpha * 0.1
    
    # Most of the work is done by the gravity and collide
    # functions.
    node
      .each(gravity(dampenedAlpha))
      .each(collide(jitter))
      .attr("transform", (d) -> "translate(#{d.x},#{d.y})")

    # As the labels are created in raw html and not svg, we need
    # to ensure we specify the 'px' for moving based on pixels
    label
      .style("left", (d) -> ((margin.left + d.x) - d.dx / 2) + "px")
      .style("top", (d) -> ((margin.top + d.y) - d.dy / 2) + "px")

  # The force variable is the force layout controlling the bubbles
  # here we disable gravity and charge as we implement custom versions
  # of gravity and collisions for this visualization
  force = d3.layout.force()
    .gravity(0)
    .charge(0)
    .size([width, height - 40])
    .on("tick", tick)

  # ---
  # Creates new chart function. This is the 'constructor' of our
  #  visualization
  # Check out http://bost.ocks.org/mike/chart/ 
  #  for a explanation and rational behind this function design
  # ---
  chart = (selection) ->
    selection.each (rawData) ->

      data = transformData(rawData)
      maxCount = d3.max(data, (d) -> d.count)
      rScale.domain([0, maxCount])

      svg = d3.select(this).selectAll("svg").data([data])
      gEnter = svg.enter().append("svg").append("g")
      
      svg.attr("width", width + margin.left + margin.right )
      svg.attr("height", height + margin.top + margin.bottom )

      g = svg.select("g")
        .attr("transform", "translate(#{margin.left},#{margin.top})")

      # node will be used to group the bubbles
      node = g.append("g").attr("id", "bubble-nodes")

      node.append("rect")
        .attr("id", "bubble-background")
        .attr("width", width)
        .attr("height", height)
        .on("click", clear)


      # label is the container div for all the labels that sit on top of 
      # the bubbles
      label = d3.select(this).selectAll("#bubble-labels").data([data])
        .enter()
        .append("div")
        .attr("id", "bubble-labels")

      update()
      hashchange()

      # automatically call hashchange when the url has changed
      d3.select(window)
        .on("hashchange", hashchange)

  # ---
  # update starts up the force directed layout and then
  # updates the nodes and labels
  # ---
  update = () ->
    # add a radius to our data nodes that will serve to determine
    # when a collision has occurred. This uses the same scale as
    # the one used to size our bubbles, but it kicks up the minimum
    # size to make it so smaller bubbles have a slightly larger 
    # collision 'sphere'
    data.forEach (d,i) ->
      d.forceR = Math.max(minCollisionRadius, rScale(rValue(d)))

    # start up the force layout
    force.nodes(data).start()

    # call our update methods to do the creation and layout work
    updateNodes()
    updateLabels()

  # ---
  # updateNodes creates a new bubble for each node in our dataset
  # ---
  updateNodes = () ->
    # here we are using the idValue function to uniquely bind our
    # data to the (currently) empty 'bubble-node selection'.
    # if you want to use your own data, you just need to modify what
    # idValue returns
    node = node.selectAll(".bubble-node").data(data, (d) -> idValue(d))

    # we don't actually remove any nodes from our data in this example 
    # but if we did, this line of code would remove them from the
    # visualization as well
    node.exit().remove()

    # nodes are just links with circles inside.
    # the styling comes from the css
    node.enter()
      .append("a")
      .attr("class", "bubble-node")
      .attr("xlink:href", (d) -> "##{encodeURIComponent(idValue(d))}")
      .call(force.drag)
      .call(link)
      .append("circle")
      .attr("r", (d) -> rScale(rValue(d)))

  # ---
  # updateLabels is more involved as we need to deal with getting the sizing
  # to work well with the font size
  # ---
  updateLabels = () ->
    # as before, we use idValue to define what the unique id for each data 
    # point is
    label = label.selectAll(".bubble-label").data(data, (d) -> idValue(d))

    label.exit().remove()

    labelEnter = label.enter().append("a")
      .attr("class", "bubble-label")
      .attr("href", (d) -> "##{encodeURIComponent(idValue(d))}")
      .call(force.drag)
      .call(link)

    labelEnter.append("div")
      .attr("class", "bubble-label-name")
      .text((d) -> textValue(d))

    labelEnter.append("div")
      .attr("class", "bubble-label-value")
      .text((d) -> d.count)

    label
      .style("font-size", (d) -> Math.max(8, rScale(rValue(d) / 2)) + "px")
      .style("width", (d) -> rScale(rValue(d)) * 2.5 + "px")

    label.append("span")
      .text((d) -> textValue(d))
      .each((d) -> d.dx = Math.max(2.5 * rScale(rValue(d)), this.getBoundingClientRect().width))
      .remove()

    label
      .style("width", (d) -> d.dx + "px")

    label.each((d) -> d.dy = this.getBoundingClientRect().height)

  # ---
  # custom gravity to skew the bubble placement
  # ---
  gravity = (alpha) ->
    cx = width / 2
    cy = height / 2
    ax = alpha / 8
    ay = alpha

    (d) ->
      d.x += (cx - d.x) * ax
      d.y += (cy - d.y) * ay

  # ---
  # ---
  collide = (alpha) ->
    q = d3.geom.quadtree(data)
    (d) ->
      r = d.forceR + maxRadius + collisionPadding
      nx1 = d.x - r
      nx2 = d.x + r
      ny1 = d.y - r
      ny2 = d.y + r
      q.visit (quad, x1, y1, x2, y2) ->
        if quad.point && (quad.point != d)
          x = d.x - quad.point.x
          y = d.y - quad.point.y
          l = Math.sqrt(x * x + y * y)
          r = d.forceR + quad.point.forceR + collisionPadding
          if l < r
            l = (l - r) / l * alpha
            x = x * l
            y = y * l
            d.x -= x
            d.y -= y
            quad.point.x += x
            quad.point.y += y
        x1 > nx2 || x2 < nx1 || y1 > ny2 || y2 < ny1
            

  # ---
  # ---
  transformData = (rawData) ->
    rawData.forEach (d) ->
      d.count = parseInt(d.count)
      rawData.sort(() -> 0.5 - Math.random())
    rawData

  # ---
  # ---
  link = (d) ->
    d.on("click", click)
    d.on("mouseover", mouseover)
    d.on("mouseout", mouseout)

  # ---
  # ---
  clear = () ->
    location.replace("#!")

  # ---
  # ---
  click = (d) ->
    location.replace("#" + encodeURIComponent(idValue(d)))
    d3.event.preventDefault()

  # ---
  # ---
  mouseover = (d) ->
    node.classed("bubble-hover", (p) -> p == d)

  # ---
  # ---
  mouseout = (d) ->
    node.classed("bubble-hover", false)

  # ---
  # ---
  hashchange = () ->
    id = decodeURIComponent(location.hash.substring(1)).trim()
    updateActive(id)

  # ---
  # ---
  updateActive = (id) ->
    active = id
    node.classed("bubble-selected", (d) -> id == idValue(d))
    d3.select("#status").html("<h3>The word <span class=\"active\">#{id}</span> is now active</h3>")

  # ---
  # ---
  chart.jitter = (_) ->
    if !arguments.length
      return jitter
    jitter = _
    force.start()
    chart

  # ---
  # ---
  chart.height = (_) ->
    if !arguments.length
      return height
    height = _
    chart

  # ---
  # ---
  chart.width = (_) ->
    if !arguments.length
      return width
    width = _
    chart

  # ---
  # ---
  chart.margin = (_) ->
    if !arguments.length
      return margin
    margin = _
    chart

  # ---
  # ---
  chart.r = (_) ->
    if !arguments.length
      return rValue
    rValue = _
    chart
  
  # final act of our main function is to
  # return the chart function we have created
  return chart

# ---
# Helper function that simplifies the calling
# of our chart with it's data and div selector
# specified
# ---
root.plotData = (selector, data, plot) ->
  d3.select(selector)
    .datum(data)
    .call(plot)

# ---
# jQuery document ready.
# ---
$ ->
  
  # create a new Bubbles chart
  plot = Bubbles()

  # ---
  # function that is called when
  # data is loaded
  # ---
  display = (data) ->
    plotData("#vis", data, plot)

  # bind change in jitter range slider
  # to update the plot's jitter
  d3.select("#jitter")
    .on "input", () ->
      plot.jitter(+this.output.value)

  # load our data
  d3.csv("data/top_sherlock.csv", display)

