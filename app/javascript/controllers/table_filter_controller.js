import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "filtersContainer", "addFilterBtn", "tableWrapper", "noResults"]
  static values = {
    columns: Array,
    table: String
  }

  connect() {
    this.filterCount = 0
    this.loadFiltersFromParams()
  }

  loadFiltersFromParams() {
    const urlParams = new URLSearchParams(window.location.search)
    const filters = []
    
    urlParams.forEach((value, key) => {
      if (key.startsWith('filter_')) {
        const match = key.match(/^filter_(\d+)_(column|operator|value)$/)
        if (match) {
          const index = parseInt(match[1])
          if (!filters[index]) filters[index] = {}
          filters[index][match[2]] = value
        }
      }
    })

    // Add valid filters
    filters.forEach(filter => {
      if (filter.column && filter.operator && (filter.value || ['is_null', 'is_not_null'].includes(filter.operator))) {
        this.addFilter(filter)
      }
    })

    if (filters.length > 0) {
      // Skip client-side filtering if server-side filtering is applied
      this.hideNoResults()
    }
  }

  addFilter(existingFilter = null) {
    const filterId = this.filterCount++
    const filterData = existingFilter || {
      column: this.columnsValue[0] || '',
      operator: 'contains',
      value: ''
    }

    const filterHtml = this.createFilterHtml(filterId, filterData)
    this.filtersContainerTarget.insertAdjacentHTML('beforeend', filterHtml)
    
    // Focus the value input if it's a new filter
    if (!existingFilter) {
      setTimeout(() => {
        const valueInput = this.filtersContainerTarget.querySelector(`[data-filter-id="${filterId}"] .filter-value`)
        if (valueInput) valueInput.focus()
      }, 100)
    }
  }

  createFilterHtml(filterId, filterData) {
    const columnOptions = this.columnsValue.map(col => 
      `<option value="${col}" ${col === filterData.column ? 'selected' : ''}>${col}</option>`
    ).join('')

    return `
      <div class="filter-item" data-filter-id="${filterId}">
        <div class="filter-fields">
          <select class="filter-column" data-action="change->table-filter#onFilterChange">
            ${columnOptions}
          </select>
          
          <select class="filter-operator" data-action="change->table-filter#onFilterChange">
            <option value="contains" ${filterData.operator === 'contains' ? 'selected' : ''}>contains</option>
            <option value="not_contains" ${filterData.operator === 'not_contains' ? 'selected' : ''}>doesn't contain</option>
            <option value="equals" ${filterData.operator === 'equals' ? 'selected' : ''}>equals</option>
            <option value="not_equals" ${filterData.operator === 'not_equals' ? 'selected' : ''}>doesn't equal</option>
            <option value="starts_with" ${filterData.operator === 'starts_with' ? 'selected' : ''}>starts with</option>
            <option value="ends_with" ${filterData.operator === 'ends_with' ? 'selected' : ''}>ends with</option>
            <option value="greater_than" ${filterData.operator === 'greater_than' ? 'selected' : ''}>greater than</option>
            <option value="less_than" ${filterData.operator === 'less_than' ? 'selected' : ''}>less than</option>
            <option value="is_null" ${filterData.operator === 'is_null' ? 'selected' : ''}>is null</option>
            <option value="is_not_null" ${filterData.operator === 'is_not_null' ? 'selected' : ''}>is not null</option>
          </select>
          
          <input type="text" 
                 class="filter-value" 
                 placeholder="Filter value..." 
                 value="${filterData.value || ''}"
                 data-action="input->table-filter#onFilterChange keydown->table-filter#onKeyDown">
        </div>
        
        <div class="filter-actions">
          <button type="button" 
                  class="filter-remove-btn" 
                  data-action="click->table-filter#removeFilter"
                  aria-label="Remove filter">
            <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path d="M6 6l12 12M18 6L6 18" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
            </svg>
          </button>
        </div>
      </div>
    `
  }

  removeFilter(event) {
    const filterItem = event.target.closest('.filter-item')
    filterItem.style.animation = 'slideOutRight 0.3s ease-out'
    
    setTimeout(() => {
      filterItem.remove()
      this.applyFilters()
    }, 300)
  }

  onFilterChange() {
    // Debounce filter changes
    clearTimeout(this.filterTimeout)
    this.filterTimeout = setTimeout(() => {
      this.applyFilters()
    }, 500)
  }

  onKeyDown(event) {
    if (event.key === 'Enter') {
      event.preventDefault()
      this.applyFilters()
    }
  }

  applyFilters() {
    const filters = this.getFilterData()
    
    // Update URL with filter parameters and reload page for server-side filtering
    this.updateUrlParams(filters)
    
    // Reload the page to apply server-side filters
    window.location.reload()
  }

  getFilterData() {
    const filterItems = this.filtersContainerTarget.querySelectorAll('.filter-item')
    return Array.from(filterItems).map(item => {
      const column = item.querySelector('.filter-column').value
      const operator = item.querySelector('.filter-operator').value
      const value = item.querySelector('.filter-value').value
      
      return { column, operator, value }
    }).filter(filter => filter.column && filter.operator && (filter.value || ['is_null', 'is_not_null'].includes(filter.operator)))
  }

  showNoResults() {
    if (!this.hasNoResultsTarget) {
      const noResultsHtml = `
        <div class="db-ide__no-results" data-table-filter-target="noResults">
          <div class="no-results-icon">
            <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
              <path d="M8 12h8" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
            </svg>
          </div>
          <h3>No results found</h3>
          <p>Try adjusting your filters or clear them to see all data.</p>
          <button type="button" class="db-ide__button db-ide__button--ghost" data-action="click->table-filter#clearAllFilters">
            Clear all filters
          </button>
        </div>
      `
      this.tableWrapperTarget.insertAdjacentHTML('beforebegin', noResultsHtml)
    }
  }

  hideNoResults() {
    if (this.hasNoResultsTarget) {
      this.noResultsTarget.remove()
    }
  }

  clearAllFilters() {
    this.filtersContainerTarget.innerHTML = ''
    this.updateUrlParams([])
    window.location.reload()
  }

  updateUrlParams(filters) {
    const url = new URL(window.location)
    const searchParams = url.searchParams

    // Remove existing filter params
    Array.from(searchParams.keys()).forEach(key => {
      if (key.startsWith('filter_')) {
        searchParams.delete(key)
      }
    })

    // Add new filter params
    filters.forEach((filter, index) => {
      searchParams.set(`filter_${index}_column`, filter.column)
      searchParams.set(`filter_${index}_operator`, filter.operator)
      searchParams.set(`filter_${index}_value`, filter.value)
    })

    // Update URL without page reload
    window.history.replaceState({}, '', url.toString())
  }
}
