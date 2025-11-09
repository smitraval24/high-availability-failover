document.addEventListener('DOMContentLoaded', () => {
  loadCoffees();
});

function loadCoffees() {
  axios.get('/coffees')
    .then(response => {
      const coffeeList = document.getElementById('coffeeList');
      coffeeList.innerHTML = ''; // Clear existing list
      
      response.data.forEach(coffee => {
        const coffeeDiv = document.createElement('div');
        coffeeDiv.className = 'coffee-item';
        coffeeDiv.id = `coffee-${coffee.id}`;
        
        coffeeDiv.innerHTML = `
          <strong>${coffee.name}</strong> - $<span id="price-${coffee.id}">${coffee.price}</span>
          <br>
          <button class="order-btn" onclick="placeOrder(${coffee.id}, '${coffee.name}')">Order</button>
          <button class="price-btn" onclick="showPriceUpdate(${coffee.id})">Change Price</button>
          <span id="price-form-${coffee.id}" style="display:none;">
            <input type="number" id="new-price-${coffee.id}" min="0.01" step="0.01" placeholder="New price">
            <button onclick="updatePrice(${coffee.id})">Update</button>
            <button onclick="cancelPriceUpdate(${coffee.id})">Cancel</button>
          </span>
        `;
        
        coffeeList.appendChild(coffeeDiv);
      });
    })
    .catch(error => {
      console.error('Error loading coffees:', error);
      alert('Error loading coffees.');
    });
}

function placeOrder(coffeeId, coffeeName) {
  axios.post('/order', { coffeeId: coffeeId, quantity: 1 })
    .then(response => {
      alert(`Ordered ${response.data.coffeeName}! Total: $${response.data.total}`);
    })
    .catch(error => {
      console.error('Error placing order:', error);
      alert('Error placing order.');
    });
}

function showPriceUpdate(coffeeId) {
  document.getElementById(`price-form-${coffeeId}`).style.display = 'inline';
}

function cancelPriceUpdate(coffeeId) {
  document.getElementById(`price-form-${coffeeId}`).style.display = 'none';
  document.getElementById(`new-price-${coffeeId}`).value = '';
}

function updatePrice(coffeeId) {
  const newPrice = document.getElementById(`new-price-${coffeeId}`).value;
  
  if (!newPrice || newPrice <= 0) {
    alert('Please enter a valid price');
    return;
  }
  
  axios.put(`/coffees/${coffeeId}/price`, { price: parseFloat(newPrice) })
    .then(response => {
      alert(`Price updated successfully! ${response.data.coffee.name} is now $${response.data.coffee.price}`);
      // Update the displayed price
      document.getElementById(`price-${coffeeId}`).textContent = response.data.coffee.price;
      // Hide the form
      cancelPriceUpdate(coffeeId);
    })
    .catch(error => {
      console.error('Error updating price:', error);
      alert('Error updating price.');
    });
}
