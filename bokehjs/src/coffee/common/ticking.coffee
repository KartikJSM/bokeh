
define [
  "underscore",
  "timezone",
  "sprintf",
], (_, tz, sprintf) ->

  log10 = (num) ->
    """
    Returns the base 10 logarithm of a number.
    """

    # prevent errors when log is 0
    if num == 0.0
      num += 1.0e-16

    return Math.log(num) / Math.LN10


  log2 = (num) ->
      """
      Returns the base 2 logarithm of a number.
      """

      # prevent errors when log is 0
      if num == 0.0
          num += 1.0e-16

      return Math.log(num) / Math.LN2

  is_base2 = (rng) ->
    """ Returns True if rng is a positive multiple of 2 """
    if rng <= 0
      false
    else
      lg = log2(rng)
      return ((lg > 0.0) and (lg == Math.floor(lg)))

  nice_2_5_10 = (x, round=false) ->
      """ if round is false, then use Math.ceil(range) """
      expv = Math.floor(log10(x))
      f = x / Math.pow(10.0, expv)
      if round
          if f < 1.5
              nf = 1.0
          else if f < 3.0
              nf = 2.0
          else if f < 7.5
              nf = 5.0
          else
              nf = 10.0
      else
          if f <= 1.0
              nf = 1.0
          else if f <= 2.0
              nf = 2.0
          else if f <= 5.0
              nf = 5.0
          else
              nf = 10.0
      return nf * Math.pow(10, expv)


  nice_10 = (x, round=false) ->
    expv = Math.floor(log10(x*1.0001))
    return Math.pow(10.0, expv)


  heckbert_interval = (min, max, numticks=8, nice=nice_2_5_10,loose=false) ->
      """
      Returns a "nice" range and interval for a given data range and a preferred
      number of ticks.  From Paul Heckbert's algorithm in Graphics Gems.
      """

      range = nice(max-min)
      d = nice(range/(numticks-1), true)

      if loose
          graphmin = Math.floor(min/d) * d
          graphmax = Math.ceil(max/d) * d
      else
          graphmin = Math.ceil(min/d) * d
          graphmax = Math.floor(max/d) * d

      return [graphmin, graphmax, d]


  arange = (start, end=false, step=false) ->
    if not end
      end = start
      start = 0
    if start > end
      if step == false
        step = -1
      else if step > 0
          "the loop will never terminate"
          1/0
    else if step < 0
      "the loop will never terminate"
      1/0
    if not step
      step = 1

    ret_arr = []
    i = start
    if start < end
      while i < end
        ret_arr.push(i)
        i += step
    else
      while i > end
        ret_arr.push(i)
        i += step
    return ret_arr

  auto_ticks_old = (data_low, data_high, bound_low, bound_high, tick_interval, use_endpoints=false, zero_always_nice=true) ->
      """ Finds locations for axis tick marks.

          Calculates the locations for tick marks on an axis. The *bound_low*,
          *bound_high*, and *tick_interval* parameters specify how the axis end
          points and tick interval are calculated.

          Parameters
          ----------

          data_low, data_high: number
              The minimum and maximum values of the data along this axis.
              If any of the bound settings are 'auto' or 'fit', the axis
              bounds are calculated automatically from these values.
          bound_low, bound_high: 'auto', 'fit', or a number.
              The lower and upper bounds of the axis. If the value is a number,
              that value is used for the corresponding end point. If the value is
              'auto', then the end point is calculated automatically. If the
              value is 'fit', then the axis bound is set to the corresponding
              *data_low* or *data_high* value.
          tick_interval: can be 'auto' or a number
              If the value is a positive number, it specifies the length
              of the tick interval; a negative integer specifies the
              number of tick intervals; 'auto' specifies that the number and
              length of the tick intervals are automatically calculated, based
              on the range of the axis.
          use_endpoints: Boolean
              If True, the lower and upper bounds of the data are used as the
              lower and upper end points of the axis. If False, the end points
              might not fall exactly on the bounds.
          zero_always_nice: Boolean
              If True, ticks much closer to zero than the tick interval will be
              coerced to have a value of zero

          Returns
          -------
          An array of tick mark locations. The first and last tick entries are the
          axis end points.
      """

      is_auto_low  = (bound_low  == 'auto')
      is_auto_high = (bound_high == 'auto')

      if typeof(bound_low) == "string"
          lower = data_low
      else
          lower = bound_low

      if typeof(bound_high) == "string"
          upper = data_high
      else
          upper = bound_high

      if (tick_interval == 'auto') or (tick_interval == 0.0)
          rng = Math.abs( upper - lower )

          if rng == 0.0
              tick_interval = 0.5
              lower         = data_low  - 0.5
              upper         = data_high + 0.5
          else if is_base2( rng ) and is_base2( upper ) and rng > 4
              if rng == 2
                  tick_interval = 1
              else if rng == 4
                  tick_interval = 4
              else
                  tick_interval = rng / 4   # maybe we want it 8?
          else
              tick_interval = auto_interval( lower, upper )
      else if tick_interval < 0
          intervals     = -tick_interval
          tick_interval = tick_intervals( lower, upper, intervals )
          if is_auto_low and is_auto_high
              is_auto_low = is_auto_high = false
              lower = tick_interval * Math.floor( lower / tick_interval )
              while ((Math.abs( lower ) >= tick_interval) and
                     ((lower + tick_interval * (intervals - 1)) >= upper))
                  lower -= tick_interval
              upper = lower + tick_interval * intervals

      # If the lower or upper bound are set to 'auto',
      # calculate them based on the newly chosen tick_interval:
      if is_auto_low or is_auto_high
          delta = 0.01 * tick_interval * (data_low == data_high)
          [auto_lower, auto_upper] = auto_bounds(
              data_low - delta, data_high + delta, tick_interval)
          if is_auto_low
              lower = auto_lower
          if is_auto_high
              upper = auto_upper

      # Compute the range of ticks values:
      start = Math.floor( lower / tick_interval ) * tick_interval
      end   = Math.floor( upper / tick_interval ) * tick_interval
      # If we return the same value for the upper bound and lower bound, the
      # layout code will not be able to lay out the tick marks (divide by zero).
      if start == end
          lower = start = start - tick_interval
          upper = end = start - tick_interval

      if upper > end
          end += tick_interval
      ticks = arange( start, end + (tick_interval / 2.0), tick_interval )

      if zero_always_nice
          for i in [0...ticks.length]
              if Math.abs(ticks[i]) < tick_interval/1000
                  ticks[i] = 0

      # FIXME
      # if len( ticks ) < 2
      #  ticks = array( ( ( lower - lower * 1.0e-7 ), lower ) )

      if (not is_auto_low) and use_endpoints
          ticks[0] = lower

      if (not is_auto_high) and use_endpoints
          ticks[ticks.length-1] = upper

      return (tick for tick in ticks when (tick >= bound_low and tick <= bound_high))

  arr_div2 = (numerator, denominators) ->
    output_arr = []
    for val in denominators
      output_arr.push(numerator/val)
    return output_arr


  arr_div3 = (numerators, denominators) ->
    output_arr = []
    for val, i in denominators
      output_arr.push(numerators[i]/val)
    return output_arr

  argsort = (arr) ->
    sorted_arr =
      _.sortBy(arr, _.identity)
    ret_arr = []
    #for y, i in arr
    #  ret_arr[i] = sorted_arr.indexOf(y)
    for y, i in sorted_arr
      ret_arr[i] = arr.indexOf(y)

      #ret_arr.push(sorted_arr.indexOf(y))
    return ret_arr

  indices = (arr) ->
    return _.range(arr.length)

  argmin = (arr) ->
    ret = _.min(indices(arr), ((i) -> return arr[i]))
    return ret

  float = (x) ->
    return x + 0.0

  # FIXME Optimize this.
  bisect_right = (xs, x) ->
    for i in [0..xs.length]
      if xs[i] > x
        return i
    return xs.length

  clamp = (x, min_val, max_val) ->
    return Math.max(min_val, Math.min(max_val, x))

  log = (x, base=Math.E) ->
    return Math.log(x) / Math.log(base)

  DESIRED_N_TICKS = 6

  # FIXME It's not clear this should be a class.
  class AbstractScale
    get_ideal_interval: (data_low, data_high) ->
      data_range = float(data_high) - float(data_low)
      return data_range / DESIRED_N_TICKS

    get_ticks: (data_low, data_high) ->
      interval = @get_interval(data_low, data_high)
      start_factor = Math.floor(data_low / interval)
      end_factor   = Math.ceil(data_high / interval)
      factors = arange(start_factor, end_factor + 1)
      ticks = factors.map((f) -> return f * interval)
      return ticks
  
  # FIXME Hopefully we won't actually need this.
  class SingleIntervalScale extends AbstractScale
    constructor: (@interval) ->

    get_min_interval: () ->
      return @interval

    get_max_interval: () ->
      return @interval

    get_interval: (data_low, data_high) ->
      return @interval

  class CompositeScale extends AbstractScale
    constructor: (@scales) ->
      # FIXME Validate that the scales don't overlap.
      @min_intervals = @scales.map((s) -> s.get_min_interval())
      @max_intervals = @scales.map((s) -> s.get_max_interval())

    get_min_interval: () ->
      return @min_intervals[0]

    get_max_interval: () ->
      return _.last(@max_intervals)

    get_best_scale: (data_low, data_high) ->
      data_range = float(data_high) - float(data_low)
      ideal_interval = @get_ideal_interval(data_low, data_high)
      scale_ixs = [
        bisect_right(@min_intervals, ideal_interval) - 1,
        bisect_right(@max_intervals, ideal_interval)
      ]
      intervals = [@min_intervals[scale_ixs[0]], @max_intervals[scale_ixs[1]]]
      errors = intervals.map((interval) ->
        return Math.abs(DESIRED_N_TICKS - (data_range / interval)))
      
      best_scale_ix = scale_ixs[argmin(errors)]
      best_scale = @scales[best_scale_ix]

      console.log("Selected #{best_scale.constructor.name}")

      return best_scale

    get_interval: (data_low, data_high) ->
      best_scale = @get_best_scale(data_low, data_high)
      return best_scale.get_interval(data_low, data_high)

    get_ticks: (data_low, data_high) ->
      best_scale = @get_best_scale(data_low, data_high)
      return best_scale.get_ticks(data_low, data_high)

  class AdaptiveScale extends AbstractScale
    constructor: (mantissas, @base=10.0, @min_magnitude=0.0,
                  @max_magnitude=Infinity)->
      @min_interval = _.first(mantissas) * @min_magnitude
      @max_interval =  _.last(mantissas) * @max_magnitude

      prefix_mantissa =  _.last(mantissas) / @base
      suffix_mantissa = _.first(mantissas) * @base
      @allowed_mantissas = _.flatten([prefix_mantissa, mantissas,
                                      suffix_mantissa])

      @base_factor = if @min_magnitude == 0.0 then 1.0 else @min_magnitude

    get_min_interval: () ->
      return @min_interval

    get_max_interval: () ->
      return @max_interval
    
    get_interval: (data_low, data_high) ->
      data_range = float(data_high) - float(data_low)
      ideal_interval = @get_ideal_interval(data_low, data_high)

      interval_exponent = Math.floor(log(ideal_interval / @base_factor, @base))
      ideal_magnitude = Math.pow(@base, interval_exponent) * @base_factor
      ideal_mantissa = ideal_interval / ideal_magnitude

      # An untested optimization.
#       index = bisect_right(@allowed_mantissas, ideal_mantissa)
#       candidate_mantissas = @allowed_mantissas[index..index + 1]
      candidate_mantissas = @allowed_mantissas

      errors = candidate_mantissas.map((mantissa) ->
        Math.abs(DESIRED_N_TICKS -
                 (data_range / (mantissa * ideal_magnitude))))
      best_mantissa = candidate_mantissas[argmin(errors)]

      interval = best_mantissa * ideal_magnitude

#       console.log("  AS.gi: mantissas = #{candidate_mantissas}")
#       console.log("            errors = #{errors}")
#       console.log("          mantissa = #{best_mantissa}")
#       console.log("         magnitude = #{ideal_magnitude}")
#       console.log("          interval = #{interval}")

      return clamp(interval, @get_min_interval(), @get_max_interval())

  last_day_no_later_than = (time) ->
    # FIXME Is this really the best way?
    d = new Date(time)
    d.setHours(0)
    d.setMinutes(0)
    d.setSeconds(0)
    d.setMilliseconds(0)
    return d.getTime()

  last_month_no_later_than = (time) ->
    d = new Date(time)
    d.setDate(1)
    d.setHours(0)
    d.setMinutes(0)
    d.setSeconds(0)
    d.setMilliseconds(0)
    return d.getTime()

  add_days = (time, n_days) ->
    d = new Date(time)
    d.setDate(d.getDate() + n_days)
    return d.getTime()

  class DayScale extends AdaptiveScale
    constructor: () ->
      super([1.0, 2.0, 5.0], 10.0, ONE_DAY, ONE_DAY)

    get_ticks: (data_low, data_high) ->
      interval = @get_interval(data_low, data_high)

      # FIXME Ideally we would walk forward using this, but we need to align
      # the days consistently.
      n_days_per_tick = interval / ONE_DAY

      tick = last_day_no_later_than(data_low)
      ticks = [tick]
      while true
        tick = add_days(tick, 1)
        ticks.push(tick)
        if tick >= data_high
          break

      console.log(ticks.map((time) -> new Date(time)))
      return ticks

  class DaysScale extends SingleIntervalScale
    constructor: (@days) ->
      typical_interval = if @days.length > 1
          (@days[1] - @days[0]) * ONE_DAY
        else
          31 * ONE_DAY
      super(typical_interval)

    get_ticks: (data_low, data_high) ->
      copy_date = (date) ->
        return new Date(date.getTime())

      date_range_by_month = (start_time, end_time) ->
        start_date = new Date(last_month_no_later_than(start_time))
        
        end_date = new Date(last_month_no_later_than(end_time))
        # XXX This is not a reliable technique in general, but it should be
        # safe when the day of the month is 1.  (The problem case is this:
        # Mar 31 -> Apr 31, which becomes May 1.)
        end_date.setMonth(end_date.getMonth() + 1)

        console.log("start: #{start_time} -> #{new Date(start_time)} -> #{start_date} -> #{start_date.getTime()}")
        console.log("  end: #{  end_time} -> #{  new Date(end_time)} -> #{  end_date} -> #{  end_date.getTime()}")

        dates = []
        date = start_date
        while true
          dates.push(copy_date(date))

          date.setMonth(date.getMonth() + 1)
          if date > end_date
            break

        return dates

      month_dates = date_range_by_month(data_low, data_high)
      console.log("months: #{month_dates}")

      days = @days
      days_of_month = (month_date) ->
        dates = []
        for day in days
          day_date = copy_date(month_date)
          day_date.setDate(day)
#           console.log("  #{day} #{day_date} (#{day_date.getMonth() == month_date.getMonth()})")
          # Some of the values of @days may not apply to the current month, in
          # which case the resulting date will fall in the next month.
          if day_date.getMonth() == month_date.getMonth()
            dates.push(day_date)
        return dates

      # FIXME Use a list comprehension?
      day_dates = _.flatten(month_dates.map((date) -> days_of_month(date)))

      console.log("  days: #{day_dates}")

      all_ticks = _.invoke(day_dates, 'getTime')
      # FIXME Since the ticks are sorted, this could be done more efficiently.
      ticks_in_range = _.filter(all_ticks,
                                ((tick) -> data_low <= tick <= data_high))

      console.log(":::")
      console.log("#{data_low} [#{all_ticks}] #{data_high}")
      console.log("[#{ ticks_in_range }]")

      # FIXME Continue here:
      # Transition between 12-hour and 24-hour resolutions is not correct.
      # This is because the day resolutions are aligned with the local time
      # zone, and the resolutions below are aligned with GMT.

      console.log("#{ticks_in_range.map((tick) -> new Date(tick))}")

      return ticks_in_range

  class SimpleScale extends CompositeScale
    constructor: (intervals) ->
      super(intervals.map((interval) ->
        return new SingleIntervalScale(interval)))

  # This is a simple one-size-fits-all scale, suitable for decimal,
  # non-time-based quantities.
#   global_scale = new AdaptiveScale([1.0, 2.0, 5.0])

  HUNDRED_MILLIS = 100.0
  ONE_SECOND = 1000.0
  ONE_MINUTE = 60.0 * ONE_SECOND
  ONE_HOUR = 60 * ONE_MINUTE
  ONE_DAY = 24 * ONE_HOUR

  global_scale = new CompositeScale([
    # Sub-second.
    # FIXME 500-ms intervals are not formatted correctly.
    new AdaptiveScale([1.0, 2.0, 5.0], 10.0, 0.0, HUNDRED_MILLIS),

    # Seconds, minutes.
    new AdaptiveScale([1.0, 2.0, 5.0, 10.0, 15.0, 20.0, 30.0], 60.0,
                      ONE_SECOND, ONE_MINUTE),

    # Hours.
    new AdaptiveScale([1.0, 2.0, 4.0, 6.0, 8.0, 12.0], 24.0,
                      ONE_HOUR, ONE_HOUR),
 
    # Days.
    # FIXME Formatting is not happening quite right at the boundaries.
    new DaysScale(arange(1, 32)), #FIXME
    new DaysScale(arange(1, 31, 3)),
    new DaysScale([1, 8, 15, 22]),
    new DaysScale([1, 15]),
    new DaysScale([1]),

    # Catchall for large timescales.
    new AdaptiveScale([1.0, 2.0, 5.0], 10.0, 10 * ONE_DAY, Infinity),
  ])

  auto_interval_temp = (data_low, data_high) ->
    return global_scale.get_interval(data_low, data_high)
  auto_ticks = (_0, _1, data_low, data_high, _2) ->
    return global_scale.get_ticks(data_low, data_high)

  auto_interval_temp_old = (data_low, data_high) ->
      """ Calculates the tick interval for a range.

          The boundaries for the data to be plotted on the axis are::

              data_bounds = (data_low,data_high)

          The function chooses the number of tick marks, which can be between
          3 and 9 marks (including end points), and chooses tick intervals at
          1, 2, 2.5, 5, 10, 20, ...

          Returns
          -------
          interval: float
              tick mark interval for axis
      """
      data_range = float(data_high) - float(data_low)
      desired_n_ticks = 6
      ideal_interval = data_range / desired_n_ticks

      ideal_magnitude = Math.pow(10, Math.floor(log10(ideal_interval)))
      ideal_mantissa = ideal_interval / ideal_magnitude

      allowed_mantissas = [0.5, 1.0, 2.0, 2.5, 5.0, 10.0]

      # Reduce the set of allowed mantissas to only the closest two.
      # FIXME Use binary search?
      # FIXME This loop should always break, but just in case something weird
      # happens with floating point, we'll set this default value.
      index = allowed_mantissas.length - 1
      for i in arange(1, allowed_mantissas.length)
        if ideal_mantissa < allowed_mantissas[i]
          index = i
          break
      # FIXME Is there some kind of slicing notation?
      candidate_mantissas = [allowed_mantissas[index - 1],
                             allowed_mantissas[index]]

      # FIXME Use absolute value here!
      errors = candidate_mantissas.map((mantissa) ->
        return desired_n_ticks - (data_range / (mantissa * ideal_magnitude)))
      best_mantissa = candidate_mantissas[argsort(errors)[0]]

      interval = best_mantissa * ideal_magnitude
        
      return interval

  # TODO (bev) restore memoization
  #auto_interval = memoize(auto_interval_temp)
  auto_interval = auto_interval_temp


  class BasicTickFormatter
    constructor: (@precision='auto', @use_scientific=true, @power_limit_high=5, @power_limit_low=-3) ->
      @scientific_limit_low  = Math.pow(10.0, power_limit_low)
      @scientific_limit_high = Math.pow(10.0, power_limit_high)
      @last_precision = 3

    format: (ticks) ->
      if ticks.length == 0
        return []

      zero_eps = 0
      if ticks.length >= 2
        zero_eps = Math.abs(ticks[1] - ticks[0]) / 10000;

      need_sci = false;
      if @use_scientific
        for tick in ticks
          tick_abs = Math.abs(tick)
          if tick_abs > zero_eps and (tick_abs >= @scientific_limit_high or tick_abs <= @scientific_limit_low)
            need_sci = true
            break

      if _.isNumber(@precision)
        labels = new Array(ticks.length)
        if need_sci
          for i in [0...ticks.length]
            labels[i] = ticks[i].toExponential(@precision)
        else
          for i in [0...ticks.length]
            labels[i] = ticks[i].toPrecision(@precision).replace(/(\.[0-9]*?)0+$/, "$1").replace(/\.$/, "")
        return labels

      else if @precision == 'auto'
        labels = new Array(ticks.length)
        for x in [@last_precision..15]
          is_ok = true
          if need_sci
            for i in [0...ticks.length]
              labels[i] = ticks[i].toExponential(x)
              if i > 0
                if labels[i] == labels[i-1]
                  is_ok = false
                  break
            if is_ok
              break
          else
            for i in [0...ticks.length]
              labels[i] = ticks[i].toPrecision(x).replace(/(\.[0-9]*?)0+$/, "$1").replace(/\.$/, "")
              if i > 0
                if labels[i] == labels[i-1]
                  is_ok = false
                  break
            if is_ok
              break

          if is_ok
            @last_precision = x
            return labels

      return labels

  _us = (t) ->
    return sprintf("%3dus", Math.floor((t % 1) * 1000))

  _ms_dot_us = (t) ->
    ms = Math.floor(((t / 1000) % 1) * 1000)
    us = Math.floor((t % 1) * 1000)
    return sprintf("%3d.%3dms", ms, us)


  _two_digit_year = (t) ->
    # Round to the nearest Jan 1, roughly.
    dt = new Date(t)
    year = dt.getFullYear()
    if dt.getMonth() >= 7
        year += 1
    return sprintf("'%02d", (year % 100))

  _four_digit_year = (t) ->
    # Round to the nearest Jan 1, roughly.
    dt = new Date(t)
    year = dt.getFullYear()
    if dt.getMonth() >= 7
        year += 1
    return sprintf("%d", year)

  _array = (t) ->
    return tz(t, "%Y %m %d %H %M %S").split(/\s+/).map( (e) -> return parseInt(e, 10) );

  _strftime = (t, format) ->
    if _.isFunction(format)
      return format(t)
    else
      return tz(t, format)

  class DatetimeFormatter

    # Labels of time units, from finest to coarsest.
    format_order: [
      'microseconds', 'milliseconds', 'seconds', 'minsec', 'minutes', 'hourmin', 'hours', 'days', 'months', 'years'
    ]

    # A dict whose are keys are the strings in **format_order**; each value is
    # two arrays, (widths, format strings/functions).

    # Whether or not to strip the leading zeros on tick labels.
    strip_leading_zeros: true

    constructor: () ->
      # This table of format is convert into the 'formats' dict.  Each tuple of
      # formats must be ordered from shortest to longest.
      @_formats = {
        'microseconds': [_us, _ms_dot_us]
        'milliseconds': ['%3Nms', '%S.%3Ns']
        'seconds':      [':%S', '%Ss']
        'minsec':       ['%M:%S']
        'minutes':      ['%Mm']
        'hourmin':      ['%H:%M']
        'hours':        ['%Hh', '%H:%M']
        'days':         ['%m/%d', '%a%d']
        'months':       ['%m/%Y', '%b%y']
        'years':        ['%Y', _two_digit_year, _four_digit_year]
      }
      @formats = {}
      for fmt_name of @_formats
        fmt_strings = @_formats[fmt_name]
        sizes = []
        tmptime = tz(new Date())
        for fmt in fmt_strings
            size = (_strftime(tmptime, fmt)).length
            sizes.push(size)
        @formats[fmt_name] = [sizes, fmt_strings]
      return

    _get_resolution: (resolution, interval) ->
      r = resolution
      span = interval
      if r < 5e-4
        resol = "microseconds"
      else if r < 0.5
        resol = "milliseconds"
      else if r < 60
        if span > 60
          resol = "minsec"
        else
          resol = "seconds"
      else if r < 3600
        if span > 3600
          resol = "hourmin"
        else
          resol = "minutes"
      else if r < 24*3600
        resol = "hours"
      else if r < 30*24*3600
        resol = "days"
      else if r < 365*24*3600
        resol = "months"
      else
        resol = "years"
      return resol

    format: (ticks, num_labels=null, char_width=null, fill_ratio=0.3, ticker=null) ->

      # In order to pick the right set of labels, we need to determine
      # the resolution of the ticks.  We can do this using a ticker if
      # it's provided, or by computing the resolution from the actual
      # ticks we've been given.
      if ticks.length == 0
          return []

      span = Math.abs(ticks[ticks.length-1] - ticks[0])/1000.0
      if ticker
        r = ticker.resolution
      else
        r = span / (ticks.length - 1)
      resol = @_get_resolution(r, span)

      [widths, formats] = @formats[resol]
      format = formats[0]
      if char_width
        # If a width is provided, then we pick the most appropriate scale,
        # otherwise just use the widest format
        good_formats = []
        for i in [0...widths.length]
          if widths[i] * ticks.length < fill_ratio * char_width
            good_formats.push(@formats[i])
        if good_formats.length > 0
          format = good_formats[ticks.length-1]

      # Apply the format to the tick values
      labels = []
      resol_ndx = @format_order.indexOf(resol)

      # This dictionary maps the name of a time resolution (in @format_order)
      # to its index in a time.localtime() timetuple.  The default is to map
      # everything to index 0, which is year.  This is not ideal; it might cause
      # a problem with the tick at midnight, january 1st, 0 a.d. being incorrectly
      # promoted at certain tick resolutions.
      time_tuple_ndx_for_resol = {}
      for fmt in @format_order
        time_tuple_ndx_for_resol[fmt] = 0
      time_tuple_ndx_for_resol["seconds"] = 5
      time_tuple_ndx_for_resol["minsec"] = 4
      time_tuple_ndx_for_resol["minutes"] = 4
      time_tuple_ndx_for_resol["hourmin"] = 3
      time_tuple_ndx_for_resol["hours"] = 3

      # As we format each tick, check to see if we are at a boundary of the
      # next higher unit of time.  If so, replace the current format with one
      # from that resolution.  This is not the best heuristic in the world,
      # but it works!  There is some trickiness here due to having to deal
      # with hybrid formats in a reasonable manner.
      for t in ticks
        try
          dt = Date(t)
          tm = _array(t)
          s = _strftime(t, format)
        catch error
          console.log error
          console.log("Unable to convert tick for timestamp " + t)
          labels.push("ERR")
          continue

        hybrid_handled = false
        next_ndx = resol_ndx

        # The way to check that we are at the boundary of the next unit of
        # time is by checking that we have 0 units of the resolution, i.e.
        # we are at zero minutes, so display hours, or we are at zero seconds,
        # so display minutes (and if that is zero as well, then display hours).
        while tm[ time_tuple_ndx_for_resol[@format_order[next_ndx]] ] == 0
          next_ndx += 1
          if next_ndx == @format_order.length
            break
          if resol in ["minsec", "hourmin"] and not hybrid_handled
            if (resol == "minsec" and tm[4] == 0 and tm[5] != 0) or (resol == "hourmin" and tm[3] == 0 and tm[4] != 0)
              next_format = @formats[@format_order[resol_ndx-1]][1][0]
              s = _strftime(t, next_format)
              break
            else
              hybrid_handled = true

          next_format = @formats[@format_order[next_ndx]][1][0]
          s = _strftime(t, next_format)

        if @strip_leading_zeros
          ss = s.replace(/^0+/g, "")
          if ss != s and (ss == '' or not isFinite(ss[0]))
            # A label such as '000ms' should leave one zero.
            ss = '0' + ss
          labels.push(ss)
        else
          labels.push(s)

      return labels

  return {
    "argsort": argsort,
    "nice_2_5_10": nice_2_5_10,
    "nice_10": nice_10,
    "heckbert_interval": heckbert_interval,
    "auto_ticks": auto_ticks,
    "auto_interval": auto_interval,
    "BasicTickFormatter": BasicTickFormatter,
    "DatetimeFormatter": DatetimeFormatter,
  }


