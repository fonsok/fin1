import { useState, useEffect } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useQuery, useMutation } from '@tanstack/react-query';
import { Card, Button } from '../../../components/ui';
import { searchCustomers, getCustomerProfile, getSupportTickets, createSupportTicket } from '../api';
import { getResponseTemplates } from '../../Templates/api';
import { TemplateDropdown, TemplateButton } from '../components/TemplateDropdown';
import { SelectedCustomerCard, CustomerSearchInput } from '../components/CustomerSelection';
import { CustomerInfoSidebar } from '../components/CustomerInfoSidebar';
import {
  defaultSubjectTemplates,
  defaultDescriptionTemplates,
  type TicketSubjectTemplate,
  type TicketDescriptionTemplate,
} from '../templates';
import type { CustomerSearchResult } from '../types';

// ============================================================================
// CreateTicketPage Component
// ============================================================================
// Page for CSR agents to create new support tickets for customers.
// Features:
// - Customer search and selection (required)
// - Text templates (Textbausteine) for subject and description
// - Category and priority selection
// - Customer info sidebar with recent tickets

export function CreateTicketPage(): JSX.Element {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const preselectedCustomerId = searchParams.get('customerId');

  // UI State
  const [customerSearch, setCustomerSearch] = useState('');
  const [selectedCustomer, setSelectedCustomer] = useState<CustomerSearchResult | null>(null);
  const [showCustomerDropdown, setShowCustomerDropdown] = useState(false);
  const [showSubjectTemplates, setShowSubjectTemplates] = useState(false);
  const [showDescriptionTemplates, setShowDescriptionTemplates] = useState(false);

  // Form State
  const [formData, setFormData] = useState({
    subject: '',
    description: '',
    category: '',
    priority: 'medium',
  });

  // Load response templates from backend (with fallback to defaults)
  const {
    data: templates,
    error: templatesError,
    isLoading: templatesLoading,
  } = useQuery({
    queryKey: ['response-templates'],
    queryFn: () => getResponseTemplates('teamlead', true),
  });

  // Use fetched templates or fallback to defaults
  const subjectTemplates: TicketSubjectTemplate[] =
    templates && templates.length > 0 ? templates : defaultSubjectTemplates;
  const descriptionTemplates: TicketDescriptionTemplate[] =
    templates && templates.length > 0
      ? templates
          .filter((t) => !!t.body && t.body.length > 0)
          .map((t) => ({ id: t.id, title: t.title, category: t.category, body: t.body! }))
      : defaultDescriptionTemplates;

  // Customer search query
  const { data: searchResults, isLoading: isSearching } = useQuery({
    queryKey: ['customer-search', customerSearch],
    queryFn: () => searchCustomers(customerSearch),
    enabled: customerSearch.length >= 2,
  });

  // Load customer profile for preview
  const { data: customerProfile } = useQuery({
    queryKey: ['customer-profile', selectedCustomer?.objectId],
    queryFn: () => getCustomerProfile(selectedCustomer!.objectId),
    enabled: !!selectedCustomer?.objectId,
  });

  // Load recent tickets for selected customer
  const { data: recentTickets } = useQuery({
    queryKey: ['customer-tickets', selectedCustomer?.objectId],
    queryFn: () => getSupportTickets(selectedCustomer!.objectId),
    enabled: !!selectedCustomer?.objectId,
  });

  // Pre-select customer if ID is provided in URL
  useEffect(() => {
    if (preselectedCustomerId) {
      getCustomerProfile(preselectedCustomerId).then((profile) => {
        if (profile) {
          setSelectedCustomer({
            objectId: profile.objectId,
            customerId: profile.customerId,
            email: profile.email,
            firstName: profile.firstName,
            lastName: profile.lastName,
            fullName: profile.fullName,
            status: profile.status,
            role: profile.role,
            kycStatus: profile.kycStatus,
          });
        }
      });
    }
  }, [preselectedCustomerId]);

  // Create ticket mutation
  const createMutation = useMutation({
    mutationFn: () =>
      createSupportTicket({
        subject: formData.subject,
        description: formData.description,
        category: formData.category,
        priority: formData.priority,
        customerId: selectedCustomer?.objectId,
        userId: selectedCustomer?.objectId,
      }),
    onSuccess: (ticket) => {
      navigate(`/csr/tickets/${ticket.objectId}`);
    },
  });

  // Constants
  const categories = [
    { value: 'technical_support', label: 'Technischer Support' },
    { value: 'account_issue', label: 'Konto-Problem' },
    { value: 'billing', label: 'Abrechnung' },
    { value: 'investment_question', label: 'Investment-Frage' },
    { value: 'trading_question', label: 'Trading-Frage' },
    { value: 'kyc_verification', label: 'KYC/Verifizierung' },
    { value: 'withdrawal', label: 'Auszahlung' },
    { value: 'deposit', label: 'Einzahlung' },
    { value: 'complaint', label: 'Beschwerde' },
    { value: 'other', label: 'Sonstiges' },
  ];

  // Helper functions
  const getKYCBadgeVariant = (status?: string): 'success' | 'warning' | 'danger' | 'neutral' => {
    switch (status) {
      case 'verified':
        return 'success';
      case 'pending':
        return 'warning';
      case 'rejected':
        return 'danger';
      default:
        return 'neutral';
    }
  };

  const getKYCLabel = (status?: string): string => {
    switch (status) {
      case 'verified':
        return 'Verifiziert';
      case 'pending':
        return 'Ausstehend';
      case 'rejected':
        return 'Abgelehnt';
      default:
        return 'Unbekannt';
    }
  };

  const handleCustomerSelect = (customer: CustomerSearchResult): void => {
    setSelectedCustomer(customer);
    setCustomerSearch('');
    setShowCustomerDropdown(false);
  };

  const handleClearCustomer = (): void => {
    setSelectedCustomer(null);
    setCustomerSearch('');
  };

  const handleSubjectTemplateSelect = (template: TicketSubjectTemplate): void => {
    setFormData({ ...formData, subject: template.title });
  };

  const handleDescriptionTemplateSelect = (template: TicketDescriptionTemplate): void => {
    const newDescription = formData.description
      ? `${formData.description}\n\n${template.body}`
      : template.body;
    setFormData({ ...formData, description: newDescription });
  };

  const isFormValid = selectedCustomer && formData.subject && formData.description && formData.category;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Neues Ticket erstellen</h1>
          <p className="text-gray-500 mt-1">Support-Anfrage für einen Kunden erfassen</p>
        </div>
        <Button variant="secondary" onClick={() => navigate('/csr/tickets')}>
          Abbrechen
        </Button>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Main Form */}
        <div className="lg:col-span-2 space-y-6">
          {/* Customer Selection */}
          <Card>
            <h2 className="text-lg font-semibold text-gray-900 mb-4">
              Kunde auswählen <span className="text-red-500">*</span>
            </h2>

            {selectedCustomer ? (
              <SelectedCustomerCard
                customer={selectedCustomer}
                onClear={handleClearCustomer}
                getKYCBadgeVariant={getKYCBadgeVariant}
                getKYCLabel={getKYCLabel}
              />
            ) : (
              <CustomerSearchInput
                value={customerSearch}
                onChange={(value) => {
                  setCustomerSearch(value);
                  setShowCustomerDropdown(true);
                }}
                onFocus={() => setShowCustomerDropdown(true)}
                showDropdown={showCustomerDropdown}
                isSearching={isSearching}
                searchResults={searchResults}
                onSelect={handleCustomerSelect}
                getKYCBadgeVariant={getKYCBadgeVariant}
                getKYCLabel={getKYCLabel}
              />
            )}
          </Card>

          {/* Ticket Details */}
          <Card>
            <h2 className="text-lg font-semibold text-gray-900 mb-4">Ticket-Details</h2>

            <form className="space-y-4">
              {/* Subject with Templates */}
              <div>
                <div className="flex items-center justify-between mb-1">
                  <label className="block text-sm font-medium text-gray-700">
                    Betreff <span className="text-red-500">*</span>
                  </label>
                  <div className="relative">
                    <TemplateButton onClick={() => setShowSubjectTemplates(!showSubjectTemplates)} />
                    {showSubjectTemplates && (
                      <TemplateDropdown
                        title="Betreff-Vorlagen"
                        templates={subjectTemplates}
                        isLoading={templatesLoading}
                        error={templatesError ? 'Fehler beim Laden der Vorlagen' : null}
                        onSelect={handleSubjectTemplateSelect}
                        onClose={() => setShowSubjectTemplates(false)}
                      />
                    )}
                  </div>
                </div>
                <input
                  type="text"
                  value={formData.subject}
                  onChange={(e) => setFormData({ ...formData, subject: e.target.value })}
                  placeholder="Kurze Beschreibung des Problems"
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary"
                />
              </div>

              {/* Description with Templates */}
              <div>
                <div className="flex items-center justify-between mb-1">
                  <label className="block text-sm font-medium text-gray-700">
                    Beschreibung <span className="text-red-500">*</span>
                  </label>
                  <div className="relative">
                    <TemplateButton onClick={() => setShowDescriptionTemplates(!showDescriptionTemplates)} />
                    {showDescriptionTemplates && (
                      <TemplateDropdown
                        title="Beschreibungs-Vorlagen"
                        templates={descriptionTemplates}
                        isLoading={templatesLoading}
                        error={templatesError ? 'Fehler beim Laden der Vorlagen' : null}
                        onSelect={handleDescriptionTemplateSelect}
                        onClose={() => setShowDescriptionTemplates(false)}
                        showBodyPreview
                        widthClass="w-80"
                      />
                    )}
                  </div>
                </div>
                <textarea
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                  placeholder="Detaillierte Beschreibung des Anliegens..."
                  className="w-full h-32 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary resize-none"
                />
              </div>

              {/* Category and Priority */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Kategorie <span className="text-red-500">*</span>
                  </label>
                  <select
                    value={formData.category}
                    onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary"
                  >
                    <option value="">Kategorie wählen...</option>
                    {categories.map((cat) => (
                      <option key={cat.value} value={cat.value}>
                        {cat.label}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Priorität</label>
                  <select
                    value={formData.priority}
                    onChange={(e) => setFormData({ ...formData, priority: e.target.value })}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary"
                  >
                    <option value="low">Niedrig</option>
                    <option value="medium">Mittel</option>
                    <option value="high">Hoch</option>
                    <option value="urgent">Dringend</option>
                  </select>
                </div>
              </div>
            </form>
          </Card>

          {/* Submit Button */}
          <div className="flex gap-3 justify-end">
            <Button variant="secondary" onClick={() => navigate('/csr/tickets')}>
              Abbrechen
            </Button>
            <Button onClick={() => createMutation.mutate()} disabled={!isFormValid || createMutation.isPending}>
              {createMutation.isPending ? 'Wird erstellt...' : 'Ticket erstellen'}
            </Button>
          </div>
        </div>

        {/* Customer Info Sidebar */}
        <CustomerInfoSidebar
          selectedCustomer={selectedCustomer}
          customerProfile={customerProfile}
          recentTickets={recentTickets}
          onNavigate={navigate}
          getKYCBadgeVariant={getKYCBadgeVariant}
          getKYCLabel={getKYCLabel}
        />
      </div>
    </div>
  );
}
