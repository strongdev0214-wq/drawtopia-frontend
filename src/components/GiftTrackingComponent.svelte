<script lang="ts">
  import basket from "../assets/Basket.svg";
  import { goto } from "$app/navigation";
  import GiftCard from "./GiftCard.svelte";

  interface GiftData {
    id: string;
    childName: string;
    ageGroup: string;
    status: 'completed' | 'generating' | 'failed' | 'waiting' | 'pending';
    giftFrom: string;
    occasion: string;
    expectedDelivery: string;
    createdAt: Date;
    sendTo?: string;
    delivery_email?: string;
    sentDate?: string;
    deliveryDate?: string;
    delivery_time?: string;
    age?: number;
    notification_sent?: boolean;
  }

  export let gifts: GiftData[] = [];
  export let loadingGifts: boolean = false;
  export let giftsError: string = "";

  console.log("gifts============================================>",gifts);

  const handlePurchaseGift = () => {
    // Navigate to the new gifts selection page
    goto("/gift/1");
  };

  // Handle gift card actions
  function handleResendLink(event: CustomEvent) {
    const { giftId } = event.detail;
    console.log(`Resending link for gift: ${giftId}`);
    // TODO: Implement resend link functionality
  }

  function handleViewGift(event: CustomEvent) {
    const { giftId } = event.detail;
    console.log(`Viewing gift: ${giftId}`);
    // TODO: Navigate to gift view page
  }

  function handleViewBook(event: CustomEvent) {
    const { giftId } = event.detail;
    console.log(`Viewing book for gift: ${giftId}`);
    // TODO: Navigate to book view page for completed gift
  }

  function handleSendThankYou(event: CustomEvent) {
    const { giftId } = event.detail;
    console.log(`Sending thank you for gift: ${giftId}`);
    // TODO: Implement send thank you functionality
  }
</script>

<div class="frame_gift_1410104151">
  <div class="frame_gift_1410104154">
    <div class="frame_gift_1410104155">
      <div class="frame_gift_1410104151_01">
        <div class="gift-tracking">
          <span class="gifttracking_span">Gift Tracking</span>
        </div>
        <div class="monitor-gift-story-creation-progress-and-delivery-status">
          <span class="monitorgiftstorycreationprogressanddeliverystatus_span"
            >Monitor gift story creation progress and delivery status</span
          >
        </div>
      </div>
      <div 
        class="frame_gift_1410103868"
        role="button"
        tabindex="0"
        on:click={handlePurchaseGift}
        on:keydown={(e) => e.key === "Enter" && handlePurchaseGift()}
      >
        <div class="basket">
          <img src={basket} alt="basket" />
        </div>
        <div class="sub-menu">
          <div class="purchase-gift">
            <span class="purchasegift_span">Purchase Gift</span>
          </div>
        </div>
      </div>
    </div>
    <div class="frame_gift_1410104170">
      {#if loadingGifts}
        <div class="loading-state">
          <div class="loading-spinner"></div>
          <p class="loading-text">Loading gifts...</p>
        </div>
      {:else if giftsError}
        <div class="error-state">
          <p class="error-text">{giftsError}</p>
          <button class="retry-button" on:click={() => window.location.reload()}>
            Try Again
          </button>
        </div>
      {:else if gifts.length === 0}
        <div class="empty-state">
          <p class="empty-text">No gifts found.</p>
          <p class="empty-subtext">Purchase your first gift to get started!</p>
        </div>
      {:else}
        <div class="gifts-grid">
          {#each gifts as gift}
            <GiftCard
              {gift}
              on:resendLink={handleResendLink}
              on:viewGift={handleViewGift}
              on:viewBook={handleViewBook}
              on:sendThankYou={handleSendThankYou}
            />
          {/each}
        </div>
      {/if}
    </div>
  </div>
</div>

<style>
  .gifttracking_span {
    color: black;
    font-size: 24px;
    font-family: Quicksand;
    font-weight: 500;
    line-height: 33.6px;
    word-wrap: break-word;
  }

  .gift-tracking {
    align-self: stretch;
  }

  .monitorgiftstorycreationprogressanddeliverystatus_span {
    color: #666d80;
    font-size: 16px;
    font-family: Quicksand;
    font-weight: 400;
    line-height: 22.4px;
    word-wrap: break-word;
  }

  .monitor-gift-story-creation-progress-and-delivery-status {
    align-self: stretch;
    height: 26px;
  }


  .purchasegift_span {
    color: white;
    font-size: 20px;
    font-family: Quicksand;
    font-weight: 500;
    line-height: 28px;
    word-wrap: break-word;
  }

  .purchase-gift {
    text-align: center;
  }

  .frame_gift_1410104151_01 {
    flex: 1 1 0;
    flex-direction: column;
    justify-content: flex-start;
    align-items: flex-start;
    gap: 4px;
    display: inline-flex;
  }

  .sub-menu {
    justify-content: center;
    align-items: center;
    gap: 10px;
    display: flex;
  }
  
  .basket {
    width: 24px;
    height: 24px;
    position: relative;
    overflow: hidden;
  }

  .frame_gift_1410103868 {
    height: 49px;
    padding-left: 16px;
    padding-right: 16px;
    padding-top: 4px;
    padding-bottom: 4px;
    background: #438bff;
    border-radius: 12px;
    justify-content: center;
    align-items: center;
    gap: 10px;
    display: flex;
    cursor: pointer;
    transition: all 0.2s ease;
    user-select: none;
    position: relative;
    overflow: hidden;
  }

  .frame_gift_1410103868:hover {
    background: #3a7ae4;
    transform: translateY(-1px);
    box-shadow: 0 2px 8px rgba(67, 139, 255, 0.3);
  }

  .frame_gift_1410103868:active {
    transform: translateY(0);
    box-shadow: 0 1px 4px rgba(67, 139, 255, 0.2);
    background: #2e6bc7;
  }

  .frame_gift_1410103868:focus {
    outline: 2px solid #438bff;
    outline-offset: 2px;
  }

  /* Ripple effect */
  /* .frame_gift_1410103868::before {
    content: '';
    position: absolute;
    top: 50%;
    left: 50%;
    width: 0;
    height: 0;
    border-radius: 50%;
    background: rgba(255, 255, 255, 0.3);
    transition: width 0.3s, height 0.3s;
    transform: translate(-50%, -50%);
    z-index: 1;
  } */

  .frame_gift_1410103868:active::before {
    width: 100px;
    height: 100px;
  }

  .frame_gift_1410103868 .basket,
  .frame_gift_1410103868 .sub-menu {
    position: relative;
    z-index: 2;
  }

  .frame_gift_1410104155 {
    align-self: stretch;
    justify-content: center;
    align-items: center;
    gap: 4px;
    display: inline-flex;
  }

  .frame_gift_1410104170 {
    align-self: stretch;
    flex-direction: column;
    justify-content: center;
    align-items: flex-start;
    gap: 40px;
    display: flex;
  }

  .frame_gift_1410104154 {
    flex: 1 1 0;
    flex-direction: column;
    justify-content: center;
    align-items: flex-start;
    gap: 24px;
    display: inline-flex;
  }

  .frame_gift_1410104151 {
    width: 100%;
    height: 100%;
    padding: 16px;
    background: white;
    border-radius: 8px;
    justify-content: center;
    align-items: center;
    gap: 4px;
    display: inline-flex;
  }

  /* Loading, Error, and Empty States */
  .loading-state,
  .error-state,
  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 40px 20px;
    text-align: center;
    width: 100%;
  }

  .loading-spinner {
    width: 40px;
    height: 40px;
    border: 4px solid #f3f3f3;
    border-top: 4px solid #438bff;
    border-radius: 50%;
    animation: spin 1s linear infinite;
    margin-bottom: 16px;
  }

  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }

  .loading-text {
    color: #666d80;
    font-size: 16px;
    font-family: Quicksand;
    font-weight: 500;
    margin: 0;
  }

  .error-text {
    color: #dc2626;
    font-size: 16px;
    font-family: Quicksand;
    font-weight: 500;
    margin: 0 0 16px 0;
  }

  .retry-button {
    padding: 8px 16px;
    background: #438bff;
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 14px;
    font-family: Quicksand;
    font-weight: 600;
    cursor: pointer;
    transition: background-color 0.2s;
  }

  .retry-button:hover {
    background: #3b7ce6;
  }

  .empty-text {
    color: #666d80;
    font-size: 18px;
    font-family: Quicksand;
    font-weight: 600;
    margin: 0 0 8px 0;
  }

  .empty-subtext {
    color: #90a1b9;
    font-size: 14px;
    font-family: Quicksand;
    font-weight: 400;
    margin: 0;
  }

  /* Gifts Grid */
  .gifts-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
    gap: 24px;
    width: 100%;
  }

  /* Mobile responsive styles */
  @media (max-width: 800px) {
    .frame_gift_1410104151 {
      width: 100%;
    }

    .frame_gift_1410104154 {
      width: 100%;
      padding: 0px;
      gap: 16px;
    }

    .frame_gift_1410104155 {
      flex-direction: column;
      align-items: flex-start;
      gap: 12px;
      width: 100%;
    }

    .frame_gift_1410104151_01 {
      width: 100%;
    }

    .gifttracking_span {
      font-size: 20px;
      line-height: 28px;
    }

    .monitorgiftstorycreationprogressanddeliverystatus_span {
      font-size: 14px;
      line-height: 19.6px;
    }

    .frame_gift_1410103868 {
      width: 100%;
      height: 49px;
      padding-left: 16px;
      padding-right: 16px;
      padding-top: 4px;
      padding-bottom: 4px;
      touch-action: manipulation;
    }

    /* Optimize button effects for mobile */
    .frame_gift_1410103868:hover {
      transform: translateY(-0.5px);
      box-shadow: 0 1px 4px rgba(67, 139, 255, 0.25);
    }

    .frame_gift_1410103868:active::before {
      width: 80px;
      height: 80px;
    }

    .purchasegift_span {
      font-size: 16px;
      line-height: 22.4px;
    }

    .frame_gift_1410104170 {
      gap: 24px;
      width: 100%;
    }

    .gifts-grid {
      grid-template-columns: 1fr;
      gap: 16px;
      width: 100%;
    }
  }
</style>
