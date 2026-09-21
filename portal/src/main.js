import './style.css'

const API_URL = 'https://naysasport.com/backend/api';

// Simple Router state
let currentUser = JSON.parse(localStorage.getItem('naysa_team') || 'null');
let players = [];
const playerPlaceholder = '/player-placeholder.svg';

const appDiv = document.querySelector('#app');

function render() {
  if (currentUser) {
    renderDashboard();
  } else {
    renderLanding();
  }
}

function showToast(msg) {
  const t = document.createElement('div');
  t.className = 'toast';
  t.innerText = msg;
  document.body.appendChild(t);
  setTimeout(() => t.remove(), 3000);
}

let isRegistering = false;
let registerStep = 1;
let registrationData = {};
let availableLeagues = [];
let registeredCredentials = null;

async function loadLeagues() {
  try {
    const res = await fetch(`${API_URL}/leagues`);
    if (res.ok) {
      availableLeagues = await res.json();
      if (isRegistering && registerStep === 1) render();
    }
  } catch (e) {
    console.warn('Could not load leagues:', e);
  }
}
loadLeagues();

async function handleRegister(e) {
  e.preventDefault();
  const formData = new FormData(e.target);
  const data = Object.fromEntries(formData.entries());
  
  // Resolve leagueName from chosen dropdown option
  const lSelect = e.target.querySelector('#leagueSelect');
  if (lSelect && lSelect.selectedIndex >= 0) {
    const opt = lSelect.options[lSelect.selectedIndex];
    if (opt && opt.dataset.name) data.leagueName = opt.dataset.name;
  }

  registrationData = { ...registrationData, ...data };
  
  const submitBtn = e.target.querySelector('button[type="submit"]');
  if (submitBtn) {
    submitBtn.innerText = 'Registering Team...';
    submitBtn.disabled = true;
  }

  try {
    const res = await fetch(`${API_URL}/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(registrationData)
    });
    const result = await res.json();
    if (res.ok && result.username && result.password) {
      registeredCredentials = result;
      registerStep = 'success';
      render();
    } else {
      showToast('Registration Error: ' + (result.error || result.message || 'Failed to register'));
      if (submitBtn) {
        submitBtn.innerText = 'Register Team (Free)';
        submitBtn.disabled = false;
      }
    }
  } catch (err) { 
    showToast('Network error while registering'); 
    if (submitBtn) {
      submitBtn.innerText = 'Register Team (Free)';
      submitBtn.disabled = false;
    }
  }
}

async function handleLogin(e) {
  e.preventDefault();
  const formData = new FormData(e.target);
  const data = Object.fromEntries(formData.entries());
  try {
    const res = await fetch(`${API_URL}/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    });
    if(res.ok) {
      currentUser = await res.json();
      localStorage.setItem('naysa_team', JSON.stringify(currentUser));
      render();
      showToast('Logged in successfully!');
    } else {
      showToast('Invalid credentials');
    }
  } catch(e) { showToast('Network error'); }
}

function logout() {
  currentUser = null;
  localStorage.removeItem('naysa_team');
  render();
}

async function fetchPlayers() {
  try {
    if (!currentUser?.token) throw new Error('Missing team session');
    const res = await fetch(`${API_URL}/team-workspace`, {
      headers: { 'Authorization': `Bearer ${currentUser.token}` }
    });
    if(res.ok) {
      const workspace = await res.json();
      players = workspace.players;
      renderPlayerGrid();
    } else if (res.status === 401) {
      logout();
      showToast('Your session expired. Please sign in again.');
    }
  } catch(e) { showToast('Unable to load your team data. Please try again.'); }
}
window.fetchPlayers = fetchPlayers;

async function handleAddPlayer(e) {
  e.preventDefault();
  const form = e.target;
  const submitBtn = form.querySelector('button[type="submit"]');
  submitBtn.innerText = 'Uploading...';
  submitBtn.disabled = true;
  
  try {
    // 1. Upload image if any
    let imageUrl = '';
    const fileInput = form.querySelector('input[type="file"]');
    if(fileInput.files.length > 0) {
      const fd = new FormData();
      fd.append('image', fileInput.files[0]);
      const upRes = await fetch(`${API_URL}/upload`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${currentUser.token}` },
        body: fd,
      });
      if(upRes.ok) {
        const upData = await upRes.json();
        imageUrl = upData.url;
      } else {
        const error = await upRes.json().catch(() => ({}));
        throw new Error(error.error || 'Photo upload failed');
      }
    }
    
    // 2. Create player
    const formData = new FormData(form);
    const data = {
      id: `p${Date.now()}`,
      name: formData.get('name'),
      age: parseInt(formData.get('age')),
      position: formData.get('position'),
      teamId: currentUser.id,
      teamName: currentUser.name,
      wardName: currentUser.wardName,
      jerseyNumber: parseInt(formData.get('jerseyNumber')),
      preferredFoot: formData.get('preferredFoot'),
      heightM: parseFloat(formData.get('heightM')),
      bio: formData.get('bio'),
      imageUrl: imageUrl
    };
    
    const res = await fetch(`${API_URL}/team-players`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${currentUser.token}` },
      body: JSON.stringify(data)
    });
    
    if(res.ok) {
      showToast('Player added successfully!');
      form.reset();
      fetchPlayers();
    } else {
      const errData = await res.json();
      showToast('Error: ' + (errData.error || 'Failed to add player'));
    }
  } catch(e) { showToast(e.message || 'Network error'); }
  
  submitBtn.innerText = 'Add Player';
  submitBtn.disabled = false;
}

function renderPlayerGrid() {
  const grid = document.getElementById('playerGrid');
  if(!grid) return;
  grid.innerHTML = players.map(p => `
    <div class="player-card" onclick="window.showPlayerCard('${p.id}')">
      <img src="${p.imageUrl && p.imageUrl !== 'null' ? p.imageUrl : `data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='200' height='200'%3E%3Crect width='200' height='200' fill='%23e8f5e9'/%3E%3Ctext x='50%25' y='50%25' dominant-baseline='middle' text-anchor='middle' font-size='60' fill='%231b5e20'%3E${p.name ? encodeURIComponent(p.name.split(' ').map(w=>w[0]).join('').toUpperCase().slice(0,2)) : '?'}%3C/text%3E%3C/svg%3E`}" class="player-photo" alt="${p.name}" onerror="this.onerror=null;this.src='${playerPlaceholder}'"/>
      <div class="player-info">
        <div class="player-name">${p.name}</div>
        <div class="player-meta"><span>${p.jerseyNumber}</span><span>${p.position}</span></div>
      </div>
      <div class="player-card-action">View</div>
    </div>
  `).join('');
}

function openAddPlayerModal() {
  if (document.querySelector('.modal-overlay.add-player-modal')) return;
  const modal = document.createElement('div');
  modal.className = 'modal-overlay add-player-modal';
  modal.innerHTML = `
    <div class="modal-content modal-form-content">
      <button class="close-modal" type="button" onclick="this.closest('.modal-overlay').remove()">
        <span class="material-icons-round">close</span>
      </button>
      <div style="margin-bottom:20px;">
        <h2 style="font-size:18px; font-weight:800;">Add New Player</h2>
        <p class="subtitle">Fill in the player details and save the new squad member.</p>
      </div>
      <form id="addPlayerFormModal" class="modal-form">
        <div class="form-group">
          <label>Player Photo</label>
          <input type="file" name="image" accept="image/*" />
        </div>
        <div class="form-group">
          <label>Name</label>
          <input type="text" name="name" required />
        </div>
        <div class="form-group">
          <label>Age</label>
          <input type="number" name="age" required />
        </div>
        <div class="form-group">
          <label>Position</label>
          <select name="position">
            <option value="Goalkeeper">Goalkeeper</option>
            <option value="Defender">Defender</option>
            <option value="Midfielder">Midfielder</option>
            <option value="Striker">Striker</option>
            <option value="Winger">Winger</option>
          </select>
        </div>
        <div class="form-group">
          <label>Jersey Number</label>
          <input type="number" name="jerseyNumber" required />
        </div>
        <div class="form-group">
          <label>Preferred Foot</label>
          <select name="preferredFoot">
            <option value="Right">Right</option>
            <option value="Left">Left</option>
            <option value="Both">Both</option>
          </select>
        </div>
        <div class="form-group">
          <label>Height (m)</label>
          <input type="number" step="0.01" name="heightM" placeholder="1.70" />
        </div>
        <div class="form-group">
          <label>Bio (Optional)</label>
          <textarea name="bio"></textarea>
        </div>
        <div style="display:flex; gap:10px; flex-wrap:wrap; margin-top:10px;">
          <button class="btn btn-outline" type="button" onclick="this.closest('.modal-overlay').remove()">Cancel</button>
          <button class="btn btn-gold" style="flex:1; justify-content:center;" type="submit">Add Player</button>
        </div>
      </form>
    </div>
  `;
  document.body.appendChild(modal);
  modal.querySelector('#addPlayerFormModal').addEventListener('submit', async (e) => {
    await handleAddPlayer(e);
    modal.remove();
  });
}

window.openAddPlayerModal = openAddPlayerModal;

window.showPlayerCard = (id) => {
  const p = players.find(x => x.id === id);
  if(!p) return;
  
  const modal = document.createElement('div');
  modal.className = 'modal-overlay';
  modal.innerHTML = `
    <div class="modal-content">
      <button class="close-modal" onclick="this.parentElement.parentElement.remove()">
        <span class="material-icons-round">close</span>
      </button>
      <div style="margin-bottom:20px;">
        <h2 style="font-size:18px; font-weight:800;">Print Player ID</h2>
        <p style="font-size:13px; color:var(--slate);">Press the print button below to print this card.</p>
      </div>
      
      <div class="id-card">
        <div class="id-header">
          <h3>${p.teamName}</h3>
          <p>Official Player Identity Card</p>
        </div>
        <div class="id-body">
          <img src="${p.imageUrl && p.imageUrl !== 'null' ? p.imageUrl : `data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='100' height='100'%3E%3Crect width='100' height='100' fill='%23e8f5e9'/%3E%3Ctext x='50%25' y='50%25' dominant-baseline='middle' text-anchor='middle' font-size='36' fill='%231b5e20'%3E${p.name ? encodeURIComponent(p.name.split(' ').map(w=>w[0]).join('').toUpperCase().slice(0,2)) : '?'}%3C/text%3E%3C/svg%3E`}" class="id-photo" alt="${p.name}" onerror="this.onerror=null;this.src='${playerPlaceholder}'"/>
          <div class="id-details">
            <div>
              <div class="id-label">Name</div>
              <div class="id-value">${p.name}</div>
            </div>
            <div>
              <div class="id-label">Position</div>
              <div class="id-value">${p.position}</div>
            </div>
            <div style="display:flex; gap:16px;">
              <div>
                <div class="id-label">Age</div>
                <div class="id-value">${p.age}</div>
              </div>
              <div>
                <div class="id-label">Squad No.</div>
                <div class="id-value">#${p.jerseyNumber}</div>
              </div>
            </div>
          </div>
        </div>
        <div class="id-footer">
          NAYSA YOUTH FOOTBALL LEAGUE
        </div>
      </div>
      
      <button class="btn btn-gold" style="width:100%; justify-content:center;" onclick="window.print()">
        <span class="material-icons-round">print</span> Print Card
      </button>
    </div>
  `;
  document.body.appendChild(modal);
}

function renderLanding() {
  let content = '';

  if (!isRegistering) {
    content = `
      <div class="card" style="max-width:420px; margin: 40px auto;">
        <div style="text-align:center; margin-bottom:24px;">
          <h1 style="font-size:24px; font-weight:800; margin-bottom:6px;">Team Portal</h1>
          <p class="subtitle" style="margin-bottom:0;">Sign in to manage your squad and match rosters.</p>
        </div>
        <form id="loginForm">
          <div class="form-group">
            <label>Username</label>
            <input type="text" name="username" required placeholder="e.g. Silver Strikers" autocomplete="username" />
          </div>
          <div class="form-group">
            <label>Password</label>
            <input type="password" name="password" required placeholder="Enter password" autocomplete="current-password" />
          </div>
          <button class="btn btn-gold" style="margin-top:12px; width:100%; justify-content:center; padding:12px;" type="submit">Sign In</button>
        </form>
        <div style="text-align:center; margin-top:24px; padding-top:16px; border-top:1px solid var(--border); font-size:13px; color:var(--slate);">
          New team?
          <a href="#" id="startRegisterBtn" style="color:var(--gold); font-weight:700; margin-left:4px;">Register here</a>
        </div>
      </div>
    `;
  } else {
    if (registerStep === 1) {
      content = `
        <div class="card" style="max-width:460px; margin: 40px auto;">
          <div style="margin-bottom:24px;">
            <h1 style="font-size:24px; font-weight:800; margin-bottom:6px;">Team Registration</h1>
            <p class="subtitle" style="margin-bottom:0;">Enter your team details and select a competition to receive your portal credentials.</p>
          </div>
          <form id="registerForm">
            <div class="form-group">
              <label>Team Name *</label>
              <input type="text" name="teamName" required placeholder="e.g. Silver Strikers" value="${registrationData.teamName || ''}" />
            </div>
            <div class="form-group">
              <label>Ward / Community *</label>
              <input type="text" name="wardName" required placeholder="e.g. Area 25, Ndirande, Chilomoni" value="${registrationData.wardName || ''}" />
            </div>
            <div class="form-group">
              <label>Coach / Manager *</label>
              <input type="text" name="coachName" required placeholder="e.g. Coach Banda" value="${registrationData.coachName || ''}" />
            </div>
            <div class="form-group">
              <label>Competition *</label>
              <select name="leagueId" id="leagueSelect" required>
                <option value="">Choose competition...</option>
                ${availableLeagues.map(l => {
                  const formatLabel = l.format === 'knockout' ? 'Cup' : (l.format === 'group_knockout' ? 'Cup & League' : 'League');
                  const selected = registrationData.leagueId === l.id ? 'selected' : '';
                  return `<option value="${l.id}" data-name="${l.name}" ${selected}>${l.name} (${formatLabel})</option>`;
                }).join('')}
              </select>
              <input type="hidden" name="leagueName" id="leagueNameInput" value="${registrationData.leagueName || ''}" />
            </div>
            <div class="form-group">
              <label>Contact Phone (Optional)</label>
              <input type="tel" name="phone" placeholder="e.g. 0999 123 456" value="${registrationData.phone || ''}" />
            </div>
            <div style="display:flex; gap:10px; margin-top:24px;">
              <button type="button" class="btn btn-outline" style="flex:1; justify-content:center;" id="cancelRegisterBtn">Cancel</button>
              <button class="btn btn-gold" style="flex:2; justify-content:center; padding:12px;" type="submit" id="submitRegisterBtn">Register Team</button>
            </div>
          </form>
        </div>
      `;
    } else if (registerStep === 'success' && registeredCredentials) {
      content = `
        <div class="card" style="max-width:460px; margin: 40px auto;">
          <div style="margin-bottom:20px;">
            <h1 style="font-size:24px; font-weight:800; margin-bottom:6px; color:var(--white);">Registration Complete</h1>
            <p class="subtitle" style="margin-bottom:0;">Your team has been registered. Save these credentials to log in.</p>
          </div>

          <div class="cred-card">
            <div class="cred-row">
              <span class="cred-label">Team</span>
              <span style="font-weight:700; color:var(--white); font-size:14px;">${registeredCredentials.team?.name || registrationData.teamName}</span>
            </div>
            <div class="cred-row">
              <span class="cred-label">Competition</span>
              <span style="font-weight:600; color:var(--gold); font-size:13px;">${registeredCredentials.team?.leagueName || 'Registered'}</span>
            </div>

            <div style="margin-top:16px;">
              <span class="cred-label">Username</span>
              <div class="cred-box">
                <span class="cred-value" id="credUsernameText">${registeredCredentials.username}</span>
                <button type="button" class="btn btn-outline btn-sm" id="copyUsernameBtn">
                  <span class="material-icons-round" style="font-size:15px;">content_copy</span> Copy
                </button>
              </div>
            </div>

            <div>
              <span class="cred-label">Password</span>
              <div class="cred-box">
                <span class="cred-value" id="credPasswordText">${registeredCredentials.password}</span>
                <button type="button" class="btn btn-outline btn-sm" id="copyPasswordBtn">
                  <span class="material-icons-round" style="font-size:15px;">content_copy</span> Copy
                </button>
              </div>
            </div>
          </div>

          <button class="btn btn-gold" style="width:100%; justify-content:center; padding:14px; font-weight:800; font-size:15px;" id="enterPortalBtn">
            Continue to Dashboard
          </button>
        </div>
      `;
    }
  }

  appDiv.innerHTML = `
    <nav class="navbar">
      <div class="logo">NAYSA Portal</div>
    </nav>
    <div class="container">
      ${content}
    </div>
  `;

  if (!isRegistering) {
    document.getElementById('loginForm').addEventListener('submit', handleLogin);
    document.getElementById('startRegisterBtn').addEventListener('click', (e) => {
      e.preventDefault();
      isRegistering = true;
      registerStep = 1;
      render();
    });
  } else {
    if (registerStep === 1) {
      document.getElementById('registerForm').addEventListener('submit', handleRegister);
      if (document.getElementById('cancelRegisterBtn')) {
        document.getElementById('cancelRegisterBtn').addEventListener('click', () => {
          isRegistering = false;
          registerStep = 1;
          registrationData = {};
          render();
        });
      }
    } else if (registerStep === 'success') {
      const enterBtn = document.getElementById('enterPortalBtn');
      if (enterBtn) {
        enterBtn.addEventListener('click', () => {
          if (registeredCredentials && registeredCredentials.team) {
            currentUser = registeredCredentials.team;
            localStorage.setItem('naysa_team', JSON.stringify(currentUser));
            isRegistering = false;
            registerStep = 1;
            registrationData = {};
            registeredCredentials = null;
            render();
            showToast('Welcome to your Team Portal!');
          }
        });
      }
      const copyUserBtn = document.getElementById('copyUsernameBtn');
      if (copyUserBtn && registeredCredentials) {
        copyUserBtn.addEventListener('click', () => {
          navigator.clipboard.writeText(registeredCredentials.username);
          copyUserBtn.innerHTML = '<span class="material-icons-round" style="font-size:15px;">check</span> Copied';
          showToast('Username copied to clipboard');
          setTimeout(() => {
            copyUserBtn.innerHTML = '<span class="material-icons-round" style="font-size:15px;">content_copy</span> Copy';
          }, 2000);
        });
      }
      const copyPassBtn = document.getElementById('copyPasswordBtn');
      if (copyPassBtn && registeredCredentials) {
        copyPassBtn.addEventListener('click', () => {
          navigator.clipboard.writeText(registeredCredentials.password);
          copyPassBtn.innerHTML = '<span class="material-icons-round" style="font-size:15px;">check</span> Copied';
          showToast('Password copied to clipboard');
          setTimeout(() => {
            copyPassBtn.innerHTML = '<span class="material-icons-round" style="font-size:15px;">content_copy</span> Copy';
          }, 2000);
        });
      }
    }
  }
}

function renderDashboard() {
  appDiv.innerHTML = `
    <nav class="navbar">
      <div class="logo">NAYSA Portal</div>
      <div class="nav-links">
        <span style="font-weight:700; color:var(--gold);">${currentUser.name}</span>
        <button class="btn btn-outline" id="logoutBtn"><span class="material-icons-round">logout</span> Logout</button>
      </div>
    </nav>
    <div class="container">
      
      <div class="portal-dashboard">
      <div class="panel panel-form">
        <div class="card" style="padding:24px;">
          <div style="display:flex; justify-content:space-between; align-items:center; gap:16px; flex-wrap:wrap;">
            <div>
              <h1>Team Roster</h1>
              <p class="subtitle">Add a player and manage your squad easily.</p>
            </div>
            <div style="display:flex; gap:10px; flex-wrap:wrap;">
              <button class="btn btn-gold" onclick="window.openAddPlayerModal()"><span class="material-icons-round">person_add</span> Add Player</button>
              <button class="btn btn-outline" onclick="fetchPlayers()"><span class="material-icons-round">refresh</span> Refresh</button>
            </div>
          </div>
        </div>
      </div>
      <div class="panel panel-roster">
        <div style="display:flex; justify-content:space-between; align-items:center; gap:16px; flex-wrap:wrap; margin-bottom:12px;">
          <div>
            <h2>Player List</h2>
            <p class="subtitle">Tap a name to view the player’s ID card.</p>
          </div>
        </div>
        <div class="player-grid" id="playerGrid">
          <p style="color:var(--slate)">Loading players...</p>
        </div>
      </div>
    </div>

    </div>
  `;
  document.getElementById('logoutBtn').addEventListener('click', logout);
  fetchPlayers();
}

window.addEventListener('DOMContentLoaded', render);
